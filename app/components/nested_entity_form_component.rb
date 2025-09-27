class NestedEntityFormComponent < ViewComponent::Base
  def initialize(child_record:, parent_record: nil, parent_id: nil, modal_id: 'nestedEntityModal',
                 child_type: nil, parent_type: nil, form_config: {})
    @child_record = child_record
    @parent_record = parent_record
    @parent_id = parent_id || parent_record&.id
    @modal_id = modal_id
    @child_type = child_type || child_record.class.name.downcase
    @parent_type = parent_type || parent_record&.class&.name&.downcase || infer_parent_type
    @form_config = form_config
  end

  private

  attr_reader :child_record, :parent_record, :parent_id, :modal_id, :child_type, :parent_type, :form_config

  def infer_parent_type
    # Try to infer parent type from child record's associations
    child_record.class.reflect_on_all_associations(:belongs_to).first&.name&.to_s
  end

  def form_url
    if child_record.persisted?
      "/#{parent_type.pluralize}/#{parent_id}/#{child_type.pluralize}/#{child_record.id}"
    else
      "/#{parent_type.pluralize}/#{parent_id}/#{child_type.pluralize}"
    end
  end

  def form_method
    child_record.persisted? ? :patch : :post
  end

  def form_title
    entity_name = form_config[:entity_name] || child_type.humanize
    child_record.persisted? ? "Edit #{entity_name}" : "Add New #{entity_name}"
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
      'nested-entity-form-target': 'form',
      'nested-entity-form-child-id-value': child_record.id || '',
      'nested-entity-form-parent-id-value': parent_id,
      'nested-entity-form-modal-id-value': modal_id,
      'nested-entity-form-child-type-value': child_type,
      'nested-entity-form-parent-type-value': parent_type
    }
  end
end