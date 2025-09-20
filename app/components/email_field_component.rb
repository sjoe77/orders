class EmailFieldComponent < FormFieldComponent
  def initialize(form:, field_name:, **options)
    super(form: form, field_name: field_name, field_type: :email, **options)
  end

  private

  def content
    form.email_field field_name, input_attributes
  end
end