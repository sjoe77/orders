class CategoriesController < ApplicationController
  include NestedAttributesProcessor

  before_action :set_category, only: [:show, :edit, :update, :destroy, :link_products]

  def index
    @pagination_result = Category.paginated_results(params)
    @categories = @pagination_result

    respond_to do |format|
      format.html
    end
  end

  def show
  end

  def new
    @category = Category.new
  end

  def edit
  end

  def create
    @category = Category.new(category_params)

    if @category.save
      redirect_to @category, notice: t('categories.created_successfully', default: 'Category was successfully created.')
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    audit_transaction = nil

    ActiveRecord::Base.transaction do
      # Use the audit reason from the form, or fall back to default
      user_reason = category_params[:audit_reason].presence || "Category update"

      # Create the audit transaction record first with user info AND parent context
      audit_transaction = AuditTransaction.create!(
        reason: user_reason,
        user_id: nil, # TODO: Set to current_user.id when authentication is implemented
        item: @category,  # Set the parent entity context
        operation_status: 'SUCCESS', # Will be updated if conflicts occur
        created_at: Time.current
      )

      # Keep whodunnit NULL for atomic transactions since user is stored in audit_transaction
      PaperTrail.request.whodunnit = nil

      # Process JSON patch if present
      merged_params = process_pending_changes(category_params)

      # Remove audit_reason from merged_params since we set it manually
      merged_params.delete(:audit_reason)

      # Extract M:M relationship changes
      product_ids = merged_params.delete('products_ids')

      # Set the audit transaction ID for all PaperTrail versions created in this request
      PaperTrail.request.controller_info = {
        audit_transaction_id: audit_transaction.id
      }

      if @category.update(merged_params)
        # Handle M:M relationship changes if present
        if product_ids.present?
          @category.product_categories.destroy_all
          product_ids.each do |product_id|
            @category.product_categories.create!(product_id: product_id)
          end
        end

        flash[:notice] = t('categories.updated_successfully', default: 'Category was successfully updated.')
        redirect_to edit_category_path(@category)
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
    @category.destroy!
    redirect_to categories_path, notice: t('categories.deleted_successfully', default: 'Category was successfully deleted.')
  rescue ActiveRecord::DeleteRestrictionError
    redirect_to categories_path, alert: t('categories.cannot_delete_has_products', default: 'Cannot delete category with existing products.')
  end

  # M:M relationship management action
  def link_products
    audit_transaction = nil
    user_reason = "Updated category products from category page"

    ActiveRecord::Base.transaction do
      # Create audit transaction
      audit_transaction = AuditTransaction.create!(
        reason: user_reason,
        user_id: nil, # TODO: Set to current_user.id when authentication is implemented
        item: @category,
        operation_status: 'SUCCESS',
        created_at: Time.current
      )

      # Set audit transaction context for PaperTrail
      PaperTrail.request.whodunnit = nil
      PaperTrail.request.controller_info = {
        audit_transaction_id: audit_transaction.id
      }

      # Get submitted product IDs from JSON array or regular array
      selected_ids_json = params[:selected_ids]
      product_ids = if selected_ids_json.present?
        JSON.parse(selected_ids_json).map(&:to_s).reject(&:blank?)
      else
        (params[:product_ids] || []).reject(&:blank?)
      end

      # Remove existing links
      @category.product_categories.destroy_all

      # Create new links
      product_ids.each do |product_id|
        @category.product_categories.create!(product_id: product_id)
      end

      render json: {
        success: true,
        message: "Products updated successfully",
        product_count: product_ids.length
      }
    end
  rescue ActiveRecord::StaleObjectError => e
    handle_link_products_conflict(e, audit_transaction)
  rescue StandardError => e
    # Update audit transaction for failure
    audit_transaction&.update!(
      operation_status: 'CONFLICT_FAILED',
      resolution_type: 'LINK_OPERATION_ERROR',
      conflict_details: { error_message: e.message }
    )
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_category
    @category = Category.find(params[:id])
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
    @category.reload

    # Extract user's intended changes from submitted params
    user_changes = category_params

    # Replay user's patches on top of fresh server state
    replay_user_patches(user_changes)

    flash.now[:alert] = t('categories.stale_conflict_resolved',
                         default: "Someone else modified this record. Your changes have been applied to the current data. Please review and save again.")
    render :edit, status: :unprocessable_entity
  end

  def build_comprehensive_conflict_details(stale_error)
    # Get current server state before user's intended changes
    original_attributes = @category.attributes_before_type_cast

    # Extract user's intended M:M relationship changes
    merged_params = process_pending_changes(category_params)
    intended_product_ids = merged_params['products_ids'] || []
    current_product_ids = @category.products.pluck(:id)

    # Build base conflict details
    base_details = {
      stale_record_type: stale_error.record.class.name,
      stale_record_id: stale_error.record.id,
      attempted_operation: stale_error.attempted_action,
      resolution_method: 'comprehensive_patch_replay',
      conflict_timestamp: Time.current.iso8601
    }

    # Add M:M relationship conflict analysis
    if intended_product_ids.present?
      mm_conflicts = build_mm_relationship_conflicts('products', intended_product_ids, current_product_ids)
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
      next if field.in?(['lock_version', 'pending_changes', 'audit_reason', 'products_ids'])

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

  def handle_link_products_conflict(stale_error, audit_transaction = nil)
    # Update audit transaction with conflict details
    if audit_transaction
      audit_transaction.update!(
        operation_status: 'CONFLICT_RESOLVED',
        resolution_type: 'AUTO_RESOLVED_LINK_CONFLICT',
        conflict_details: {
          stale_record_type: stale_error.record.class.name,
          attempted_operation: 'link_products',
          resolution_method: 'retry_with_fresh_data'
        }
      )
    end

    render json: {
      error: "Product links were modified by another user. Please refresh and try again.",
      conflict: true
    }, status: :conflict
  end

  def replay_user_patches(user_changes)
    # Process pending changes to extract all user intentions
    merged_params = process_pending_changes(user_changes)

    # Apply parent entity field changes
    apply_parent_patches(merged_params.except('products_ids'))

    # Apply M:M relationship patches
    if merged_params['products_ids'].present?
      replay_mm_relationship_patches('products', merged_params['products_ids'])
    end
  end

  def apply_parent_patches(parent_changes)
    parent_changes.each do |key, value|
      next if key.to_s.in?(['lock_version', 'pending_changes', 'audit_reason'])
      @category.assign_attributes(key => value)
    end
  end

  def replay_mm_relationship_patches(relationship_name, intended_ids)
    # Store user's intended M:M state for display during conflict resolution
    # This ensures the relationship table shows user's pending changes
    @category.instance_variable_set("@pending_#{relationship_name}_ids", intended_ids)

    # Also store in pending_changes for form field population
    preserved_changes = { "#{relationship_name}_ids" => intended_ids }
    @category.pending_changes = preserved_changes.to_json
  end

  def category_params
    params.require(:category).permit(
      :name_nm, :description_txt, :parent_category_id, :display_order_num,
      :active_flag, :lock_version, :pending_changes, :audit_reason
    )
  end
end