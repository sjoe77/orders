class OrdersController < ApplicationController
  before_action :set_customer, only: [:index]

  def index
    @orders = @customer.orders.includes(:customer)
                      .apply_table_sorting(params)
    @pagination_result = @orders.paginated_results(params)
    @orders = @pagination_result

    respond_to do |format|
      format.html { render layout: false }
      format.turbo_stream
    end
  end

  private

  def set_customer
    @customer = Customer.find(params[:customer_id]) if params[:customer_id]
  end
end