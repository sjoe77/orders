class CustomersController < ApplicationController
  before_action :set_customer, only: [:show, :edit, :update, :destroy]

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
    if @customer.update(customer_params)
      redirect_to @customer, notice: t('customers.updated_successfully')
    else
      render :edit, status: :unprocessable_entity
    end
  rescue ActiveRecord::StaleObjectError
    redirect_to edit_customer_path(@customer),
                alert: t('customers.stale_object_error')
  end

  def destroy
    @customer.destroy!
    redirect_to customers_path, notice: t('customers.deleted_successfully')
  rescue ActiveRecord::DeleteRestrictionError
    redirect_to customers_path, alert: t('customers.cannot_delete_has_orders')
  end

  private

  def set_customer
    @customer = Customer.find(params[:id])
  end

  def customer_params
    params.require(:customer).permit(
      :customer_key_nm, :company_name_nm, :contact_first_name_nm,
      :contact_last_name_nm, :email_nm, :phone_num, :tax_id_num,
      :credit_limit_amt, :active_flag, :lock_version,
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
