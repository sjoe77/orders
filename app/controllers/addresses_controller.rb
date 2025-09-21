class AddressesController < ApplicationController
  before_action :set_customer
  before_action :set_address, only: [:show, :edit, :update, :destroy]

  def index
    @addresses = @customer.addresses.includes(:customer)
                         .apply_table_sorting(params)
    @pagination_result = @addresses.paginated_results(params)
    @addresses = @pagination_result

    respond_to do |format|
      format.html { render layout: false }
      format.turbo_stream
    end
  end

  def new
    @address = @customer.addresses.build

    respond_to do |format|
      format.html { render layout: false if turbo_frame_request? }
    end
  end

  def edit
    respond_to do |format|
      format.html { render layout: false if turbo_frame_request? }
    end
  end

  def create
    # For nested addresses via customer, redirect back to customer edit
    # The actual save will happen through customer's nested_attributes
    redirect_to edit_customer_path(@customer),
                notice: 'Address changes prepared. Save customer to complete.'
  end

  def update
    # For nested addresses via customer, redirect back to customer edit
    # The actual save will happen through customer's nested_attributes
    redirect_to edit_customer_path(@customer),
                notice: 'Address changes prepared. Save customer to complete.'
  end

  def destroy
    # For nested addresses via customer, redirect back to customer edit
    redirect_to edit_customer_path(@customer),
                notice: 'Address will be removed when customer is saved.'
  end

  private

  def set_customer
    @customer = Customer.find(params[:customer_id])
  end

  def set_address
    @address = @customer.addresses.find(params[:id])
  end

  def address_params
    params.require(:address).permit(:address_type_nm, :address_line1_txt, :address_line2_txt,
                                   :city_nm, :state_nm, :postal_code_nm, :country_code_nm, :is_default_flag)
  end
end