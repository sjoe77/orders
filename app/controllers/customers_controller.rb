class CustomersController < ApplicationController
  include NestedAttributesProcessor

  before_action :set_customer, only: [:show, :edit, :update, :destroy, :audit, :audit_page]

  def index
    
    @pagination_result = Customer.paginated_results(params)
    @customers = @pagination_result

    respond_to do |format|
      format.html
    end
  end

  def show
  end

  def new
    @customer = Customer.new
    @customer.addresses.build(address_type_nm: 'billing')
    @customer.addresses.build(address_type_nm: 'shipping')
  end

  def edit
  end

  def create
    @customer = Customer.new(customer_params)

    if @customer.save
      redirect_to @customer, notice: t('customers.created_successfully')
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    reason_key = SecureRandom.uuid

    ActiveRecord::Base.transaction do
      # Use the audit reason from the form, or fall back to default
      user_reason = customer_params[:audit_reason].presence || "Customer and addresses update"
      Rails.logger.info "🔍 DEBUG: user_reason = #{user_reason.inspect}"

      # Log the raw parameters received
      Rails.logger.info "🔍 DEBUG: Raw customer_params = #{customer_params.to_h}"
      Rails.logger.info "🔍 DEBUG: addresses_attributes present? = #{customer_params[:addresses_attributes].present?}"
      if customer_params[:addresses_attributes].present?
        Rails.logger.info "🔍 DEBUG: addresses_attributes = #{customer_params[:addresses_attributes].to_h}"
      end

      # Process JSON patch if present
      merged_params = process_pending_changes(customer_params)

      # Remove audit_reason from merged_params since we set it manually
      merged_params.delete(:audit_reason)
      Rails.logger.info "🔍 DEBUG: merged_params keys = #{merged_params.keys}"
      Rails.logger.info "🔍 DEBUG: merged_params addresses_attributes = #{merged_params[:addresses_attributes]&.to_h}"

      # Set reason and perform update
      reason_text = "#{user_reason} - #{reason_key}"
      Rails.logger.info "🔍 DEBUG: reason_text = #{reason_text.inspect}"

      if @customer.update(merged_params)
        # Update the most recent version with our custom reason
        latest_version = @customer.versions.last
        if latest_version
          latest_version.update(reason: reason_text)
          Rails.logger.info "🔍 DEBUG: Updated version #{latest_version.id} with reason: #{reason_text}"
        end

        # Use regular flash and redirect to ensure success message shows after reload
        flash[:notice] = t('customers.updated_successfully')
        redirect_to edit_customer_path(@customer)
      else
        render :edit, status: :unprocessable_entity
      end
    end
  rescue ActiveRecord::StaleObjectError
    handle_stale_object_conflict
  rescue ActiveRecord::RecordInvalid => e
    render :edit, status: :unprocessable_entity, alert: "Update failed: #{e.message}"
  end

  def destroy
    @customer.destroy!
    redirect_to customers_path, notice: t('customers.deleted_successfully')
  rescue ActiveRecord::DeleteRestrictionError
    redirect_to customers_path, alert: t('customers.cannot_delete_has_orders')
  end

  def audit
    @versions = @customer.versions.includes(:item).reorder(created_at: :desc)

    # Group versions by reason (if available)
    @grouped_versions = @versions.group_by { |v| v.reason || 'No reason provided' }

    render layout: false
  end

  def audit_page
    page = params[:page].to_i
    page = 1 if page < 1

    component = AuditHistoryViewerComponent.new(
      record: @customer,
      page: page,
      max_entries: 5,
      show_details: true,
      collapsed: true
    )

    render html: component.render_in(view_context).html_safe, layout: false
  end

  private

  def set_customer
    @customer = Customer.find(params[:id])
  end

  def handle_stale_object_conflict
    # Reload fresh data from server
    @customer.reload

    # Extract user's intended changes from submitted params
    user_changes = customer_params

    # Replay user's patches on top of fresh server state
    replay_user_patches(user_changes)

    flash.now[:alert] = t('customers.stale_conflict_resolved',
                         default: "Someone else modified this record. Your changes have been applied to the current data. Please review and save again.")
    render :edit, status: :unprocessable_entity
  end

  def replay_user_patches(user_changes)
    # Apply parent entity field changes (customer fields)
    parent_changes = user_changes.except(*nested_attribute_keys(user_changes))
    apply_parent_patches(parent_changes)

    # Handle nested relationship patches generically
    nested_attribute_keys(user_changes).each do |relationship_key|
      relationship_name = relationship_key.to_s.gsub('_attributes', '')
      replay_relationship_patches(relationship_name, user_changes[relationship_key])
    end
  end

  def nested_attribute_keys(params)
    params.keys.select { |key| key.to_s.end_with?('_attributes') }
  end

  def apply_parent_patches(parent_changes)
    parent_changes.each do |key, value|
      next if key.to_s.in?(['lock_version', 'pending_changes', 'audit_reason'])
      @customer.assign_attributes(key => value)
    end
  end

  def replay_relationship_patches(relationship_name, relationship_patches)
    relationship_patches.each do |index, attrs|
      record_id = attrs[:id]

      if attrs[:_destroy] == '1'
        # User wanted to delete this record
        association = @customer.send(relationship_name)
        record = association.find_by(id: record_id)
        record&.mark_for_destruction
      elsif record_id.present?
        # User wanted to update existing record
        association = @customer.send(relationship_name)
        record = association.find_by(id: record_id)
        if record
          record.assign_attributes(attrs.except(:id, :_destroy))
        end
      else
        # User wanted to add new record
        association = @customer.send(relationship_name)
        association.build(attrs.except(:id, :_destroy))
      end
    end
  end

  def customer_params
    params.require(:customer).permit(
      :customer_key_nm, :company_name_nm, :contact_first_name_nm,
      :contact_last_name_nm, :email_nm, :phone_num, :tax_id_num,
      :credit_limit_amt, :active_flag, :lock_version, :pending_changes, :audit_reason,
      addresses_attributes: [
        :id, :address_type_nm, :address_line1_txt, :address_line2_txt,
        :city_nm, :state_nm, :postal_code_nm, :country_code_nm,
        :is_default_flag, :_destroy
      ]
    )
  end

  def export_csv
    csv_data = generate_csv_export(Customer.apply_table_filters(params).apply_table_sorting(params))
    send_data csv_data,
              filename: "customers-#{Date.current}.csv",
              type: 'text/csv'
  end

  def export_xlsx
    # Implementation would use caxlsx gem
    redirect_to customers_path, alert: 'Excel export not implemented yet'
  end


  def generate_csv_export(customers)
    require 'csv'

    CSV.generate(headers: true) do |csv|
      csv << [
        t('attributes.customer.customer_key_nm'),
        t('attributes.customer.company_name_nm'),
        t('attributes.customer.contact_first_name_nm'),
        t('attributes.customer.contact_last_name_nm'),
        t('attributes.customer.email_nm'),
        t('attributes.customer.phone_num'),
        t('attributes.customer.credit_limit_amt'),
        t('attributes.customer.active_flag')
      ]

      customers.find_each do |customer|
        csv << [
          customer.customer_key_nm,
          customer.company_name_nm,
          customer.contact_first_name_nm,
          customer.contact_last_name_nm,
          customer.email_nm,
          customer.phone_num,
          customer.credit_limit_amt,
          customer.active_flag
        ]
      end
    end
  end
end
