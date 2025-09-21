class AddressesController < ApplicationController
  before_action :set_customer

  def index
    # Get addresses for this customer with sorting and pagination
    addresses = @customer.addresses

    # Apply sorting if provided
    if params[:sort].present? && Address.column_names.include?(params[:sort])
      direction = params[:direction] == 'desc' ? 'desc' : 'asc'
      addresses = addresses.order("#{params[:sort]} #{direction}")
    end

    # Render just the relationship table component
    render RelationshipTableComponent.new(
      title: "Addresses",
      records: addresses,
      current_params: params,
      actions: {
        create: true,
        edit: true,
        delete: true,
        create_action: {
          event: true,
          label: "Add Address"
        },
        edit_action: {
          event: true
        },
        delete_action: {
          event: true
        }
      }
    )
  end

  private

  def set_customer
    @customer = Customer.find(params[:customer_id])
  end
end