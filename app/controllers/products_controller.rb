class ProductsController < ApplicationController
  include NestedAttributesProcessor

  before_action :set_product, only: [:show, :edit, :update, :destroy, :link_categories, :categories_modal]

  def index
    @pagination_result = Product.paginated_results(params)
    @products = @pagination_result

    respond_to do |format|
      format.html
    end
  end

  def show
  end

  def new
    @product = Product.new
  end

  def edit
  end

  def create
    @product = Product.new(product_params)

    if @product.save
      redirect_to @product, notice: t('products.created_successfully', default: 'Product was successfully created.')
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    audit_transaction = nil

    ActiveRecord::Base.transaction do
      # Use the audit reason from the form, or fall back to default
      user_reason = product_params[:audit_reason].presence || "Product update"
      Rails.logger.info "🔍 DEBUG: user_reason = #{user_reason.inspect}"

      # Create the audit transaction record first with user info AND parent context
      audit_transaction = AuditTransaction.create!(
        reason: user_reason,
        user_id: nil, # TODO: Set to current_user.id when authentication is implemented
        item: @product,  # Set the parent entity context
        operation_status: 'SUCCESS', # Will be updated if conflicts occur
        created_at: Time.current
      )

      # Keep whodunnit NULL for atomic transactions since user is stored in audit_transaction
      PaperTrail.request.whodunnit = nil

      # Process JSON patch if present
      merged_params = process_pending_changes(product_params)

      # Remove audit_reason from merged_params since we set it manually
      merged_params.delete(:audit_reason)

      # Separate M:M relationship IDs from other params
      mm_relationship_params = merged_params.select { |k, v| k.end_with?('_ids') }
      parent_params = merged_params.except(*mm_relationship_params.keys)

      # Set the audit transaction ID for all PaperTrail versions created in this request
      PaperTrail.request.controller_info = {
        audit_transaction_id: audit_transaction.id
      }

      # Update parent entity first, then handle M:M relationships
      if @product.update(parent_params)
        # Apply M:M relationship changes after parent entity is updated
        mm_relationship_params.each do |relationship_key, ids|
          # relationship_key is "categories_ids", we want to call "category_ids="
          # Remove "_ids" suffix, singularize the relationship name, then add "_ids" back
          relationship_name = relationship_key.gsub('_ids', '') # "categories_ids" -> "categories"
          singular_relationship = relationship_name.singularize # "categories" -> "category"
          method_name = "#{singular_relationship}_ids" # "category_ids"
          @product.send("#{method_name}=", ids)
        end

        flash[:notice] = t('products.updated_successfully', default: 'Product was successfully updated.')
        redirect_to edit_product_path(@product)
      else
        render :edit, status: :unprocessable_entity
      end
    end
  rescue ActiveRecord::StaleObjectError => e
    handle_stale_object_conflict(e, audit_transaction)
  rescue ActiveRecord::RecordInvalid => e
    # Update audit transaction for validation failure
    audit_transaction&.update!(
      operation_status: 'CONFLICT_FAILED',
      resolution_type: 'VALIDATION_ERROR',
      conflict_details: { error_message: e.message, errors: e.record.errors.full_messages }
    )
    render :edit, status: :unprocessable_entity, alert: "Update failed: #{e.message}"
  end

  def destroy
    @product.destroy!
    redirect_to products_path, notice: t('products.deleted_successfully', default: 'Product was successfully deleted.')
  rescue ActiveRecord::DeleteRestrictionError
    redirect_to products_path, alert: t('products.cannot_delete_has_orders', default: 'Cannot delete product with existing orders.')
  end

  # M:M relationship management action
  def link_categories
    audit_transaction = nil
    user_reason = "Updated product categories from product page"

    ActiveRecord::Base.transaction do
      # Create audit transaction
      audit_transaction = AuditTransaction.create!(
        reason: user_reason,
        user_id: nil, # TODO: Set to current_user.id when authentication is implemented
        item: @product,
        operation_status: 'SUCCESS',
        created_at: Time.current
      )

      # Set audit transaction context for PaperTrail
      PaperTrail.request.whodunnit = nil
      PaperTrail.request.controller_info = {
        audit_transaction_id: audit_transaction.id
      }

      # Get submitted category IDs from JSON array or regular array
      selected_ids_json = params[:selected_ids]
      category_ids = if selected_ids_json.present?
        JSON.parse(selected_ids_json).map(&:to_s).reject(&:blank?)
      else
        (params[:category_ids] || []).reject(&:blank?)
      end

      # Remove existing links
      @product.product_categories.destroy_all

      # Create new links
      category_ids.each do |category_id|
        @product.product_categories.create!(category_id: category_id)
      end

      render json: {
        success: true,
        message: "Categories updated successfully",
        category_count: category_ids.length
      }
    end
  rescue ActiveRecord::StaleObjectError => e
    handle_link_categories_conflict(e, audit_transaction)
  rescue StandardError => e
    # Update audit transaction for failure
    audit_transaction&.update!(
      operation_status: 'CONFLICT_FAILED',
      resolution_type: 'LINK_OPERATION_ERROR',
      conflict_details: { error_message: e.message }
    )
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # Render modal content for category selection
  def categories_modal
    @available_categories = Category.active.order(:display_order_num, :name_nm)
    @current_category_ids = @product.categories.pluck(:id)

    render layout: false
  end

  private

  def set_product
    @product = Product.find(params[:id])
  end

  def handle_stale_object_conflict(stale_error, audit_transaction = nil)
    # Build comprehensive conflict details including M:M relationships
    conflict_details = build_comprehensive_conflict_details(stale_error)

    # Update audit transaction with detailed conflict information
    if audit_transaction
      audit_transaction.update!(
        operation_status: 'CONFLICT_RESOLVED',
        resolution_type: 'AUTO_RESOLVED_COMPREHENSIVE_PATCH_REPLAY',
        conflict_details: conflict_details
      )
    end

    # Reload fresh data from server
    @product.reload

    # Extract user's intended changes from submitted params
    user_changes = product_params

    # Replay user's patches on top of fresh server state
    replay_user_patches(user_changes)

    flash.now[:alert] = t('products.stale_conflict_resolved',
                         default: "Someone else modified this record. Your changes have been applied to the current data. Please review and save again.")
    render :edit, status: :unprocessable_entity
  end

  def build_comprehensive_conflict_details(stale_error)
    # Get current server state before user's intended changes
    original_attributes = @product.attributes_before_type_cast

    # Extract user's intended M:M relationship changes
    merged_params = process_pending_changes(product_params)
    intended_category_ids = merged_params['categories_ids'] || []
    current_category_ids = @product.categories.pluck(:id)

    # Build base conflict details
    base_details = {
      stale_record_type: stale_error.record.class.name,
      stale_record_id: stale_error.record.id,
      attempted_operation: stale_error.attempted_action,
      resolution_method: 'comprehensive_patch_replay',
      conflict_timestamp: Time.current.iso8601
    }

    # Add M:M relationship conflict analysis
    if intended_category_ids.present?
      mm_conflicts = build_mm_relationship_conflicts('categories', intended_category_ids, current_category_ids)
      base_details[:mm_relationship_conflicts] = mm_conflicts if mm_conflicts.any?
    end

    # Add field-level conflict analysis
    field_conflicts = build_field_level_conflicts(original_attributes, merged_params)
    base_details[:field_conflicts] = field_conflicts if field_conflicts.any?

    base_details
  end

  def build_mm_relationship_conflicts(relationship_name, intended_ids, current_ids)
    conflicts = []

    # Detect concurrent link operations (items linked by another user while this user was editing)
    concurrent_links = current_ids - intended_ids
    if concurrent_links.any?
      conflicts << {
        conflict_type: 'concurrent_link',
        relationship: relationship_name,
        affected_ids: concurrent_links,
        description: "#{concurrent_links.length} #{relationship_name} were linked by another user"
      }
    end

    # Detect concurrent unlink operations (items unlinked by another user while this user was editing)
    concurrent_unlinks = intended_ids - current_ids
    if concurrent_unlinks.any?
      conflicts << {
        conflict_type: 'concurrent_unlink',
        relationship: relationship_name,
        affected_ids: concurrent_unlinks,
        description: "#{concurrent_unlinks.length} #{relationship_name} were unlinked by another user"
      }
    end

    conflicts
  end

  def build_field_level_conflicts(original_attributes, user_intended_changes)
    conflicts = []

    user_intended_changes.each do |field, intended_value|
      next if field.in?(['lock_version', 'pending_changes', 'audit_reason', 'categories_ids'])

      original_value = original_attributes[field]
      if original_value != intended_value
        conflicts << {
          field: field,
          original_value: original_value,
          intended_value: intended_value,
          conflict_type: 'field_modification'
        }
      end
    end

    conflicts
  end

  def handle_link_categories_conflict(stale_error, audit_transaction = nil)
    # Update audit transaction with conflict details
    if audit_transaction
      audit_transaction.update!(
        operation_status: 'CONFLICT_RESOLVED',
        resolution_type: 'AUTO_RESOLVED_LINK_CONFLICT',
        conflict_details: {
          stale_record_type: stale_error.record.class.name,
          attempted_operation: 'link_categories',
          resolution_method: 'retry_with_fresh_data'
        }
      )
    end

    render json: {
      error: "Category links were modified by another user. Please refresh and try again.",
      conflict: true
    }, status: :conflict
  end

  def replay_user_patches(user_changes)
    # Process pending changes to extract all user intentions
    merged_params = process_pending_changes(user_changes)

    # Separate M:M relationship IDs from other params
    mm_relationship_params = merged_params.select { |k, v| k.end_with?('_ids') }
    parent_params = merged_params.except(*mm_relationship_params.keys)

    # Apply parent entity field changes
    apply_parent_patches(parent_params)

    # Apply M:M relationship patches for all relationships
    mm_relationship_params.each do |relationship_key, ids|
      relationship_name = relationship_key.gsub('_ids', '')
      replay_mm_relationship_patches(relationship_name, ids)
    end
  end

  def apply_parent_patches(parent_changes)
    parent_changes.each do |key, value|
      next if key.to_s.in?(['lock_version', 'pending_changes', 'audit_reason'])
      @product.assign_attributes(key => value)
    end
  end

  def replay_mm_relationship_patches(relationship_name, intended_ids)
    # Store user's intended M:M state for display during conflict resolution
    # This ensures the relationship table shows user's pending changes
    @product.instance_variable_set("@pending_#{relationship_name}_ids", intended_ids)

    # Also store in pending_changes for form field population
    preserved_changes = { "#{relationship_name}_ids" => intended_ids }
    @product.pending_changes = preserved_changes.to_json
  end


  def product_params
    params.require(:product).permit(
      :product_key_nm, :sku_nm, :name_nm, :description_txt, :unit_price_amt,
      :cost_amt, :weight_num, :dimensions_json, :active_flag, :lock_version,
      :pending_changes, :audit_reason
    )
  end
end