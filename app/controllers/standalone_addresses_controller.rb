class StandaloneAddressesController < ApplicationController
  before_action :set_address, only: [:show, :edit, :update, :destroy]

  def index
    @addresses = Address.includes(:customer)
                       .apply_table_sorting(params)
    @pagination_result = @addresses.paginated_results(params)
    @addresses = @pagination_result
  end

  def new
    @address = Address.new
  end

  def create
    @address = Address.new(address_params)

    if @address.save
      redirect_to addresses_path, notice: 'Address was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @address.update(address_params)
      redirect_to addresses_path, notice: 'Address was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @address.destroy
    redirect_to addresses_path, notice: 'Address was successfully deleted.'
  end

  private

  def set_address
    @address = Address.find(params[:id])
  end

  def address_params
    params.require(:address).permit(:customer_id, :address_type_nm, :address_line1_txt, :address_line2_txt,
                                   :city_nm, :state_nm, :postal_code_nm, :country_code_nm, :is_default_flag)
  end
end