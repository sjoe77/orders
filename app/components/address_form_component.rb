class AddressFormComponent < ViewComponent::Base
  def initialize(address:, customer_id: nil, modal_id: 'addressModal')
    @address = address
    @customer_id = customer_id
    @modal_id = modal_id
  end

  private

  attr_reader :address, :customer_id, :modal_id

  def form_url
    if address.persisted?
      "/customers/#{customer_id}/addresses/#{address.id}"
    else
      "/customers/#{customer_id}/addresses"
    end
  end

  def form_method
    address.persisted? ? :patch : :post
  end

  def form_title
    address.persisted? ? 'Edit Address' : 'Add New Address'
  end

  def address_type_options
    [
      ['Shipping', 'shipping'],
      ['Billing', 'billing']
    ]
  end

  def country_options
    [
      ['United States', 'US'],
      ['Canada', 'CA'],
      ['Mexico', 'MX']
    ]
  end

  def state_options
    [
      ['Alabama', 'AL'], ['Alaska', 'AK'], ['Arizona', 'AZ'], ['Arkansas', 'AR'],
      ['California', 'CA'], ['Colorado', 'CO'], ['Connecticut', 'CT'], ['Delaware', 'DE'],
      ['Florida', 'FL'], ['Georgia', 'GA'], ['Hawaii', 'HI'], ['Idaho', 'ID'],
      ['Illinois', 'IL'], ['Indiana', 'IN'], ['Iowa', 'IA'], ['Kansas', 'KS'],
      ['Kentucky', 'KY'], ['Louisiana', 'LA'], ['Maine', 'ME'], ['Maryland', 'MD'],
      ['Massachusetts', 'MA'], ['Michigan', 'MI'], ['Minnesota', 'MN'], ['Mississippi', 'MS'],
      ['Missouri', 'MO'], ['Montana', 'MT'], ['Nebraska', 'NE'], ['Nevada', 'NV'],
      ['New Hampshire', 'NH'], ['New Jersey', 'NJ'], ['New Mexico', 'NM'], ['New York', 'NY'],
      ['North Carolina', 'NC'], ['North Dakota', 'ND'], ['Ohio', 'OH'], ['Oklahoma', 'OK'],
      ['Oregon', 'OR'], ['Pennsylvania', 'PA'], ['Rhode Island', 'RI'], ['South Carolina', 'SC'],
      ['South Dakota', 'SD'], ['Tennessee', 'TN'], ['Texas', 'TX'], ['Utah', 'UT'],
      ['Vermont', 'VT'], ['Virginia', 'VA'], ['Washington', 'WA'], ['West Virginia', 'WV'],
      ['Wisconsin', 'WI'], ['Wyoming', 'WY']
    ]
  end

  def form_data_attributes
    {
      'address-form-target': 'form',
      'address-form-address-id-value': address.id || '',
      'address-form-customer-id-value': customer_id,
      'address-form-modal-id-value': modal_id
    }
  end
end