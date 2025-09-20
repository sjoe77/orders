class TelephoneFieldComponent < FormFieldComponent
  def initialize(form:, field_name:, **options)
    super(form: form, field_name: field_name, field_type: :tel, **options)
  end

  private

  def content
    form.telephone_field field_name, input_attributes
  end
end