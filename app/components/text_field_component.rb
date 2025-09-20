class TextFieldComponent < FormFieldComponent
  def initialize(form:, field_name:, **options)
    super(form: form, field_name: field_name, field_type: :text, **options)
  end

  private

  def content
    form.text_field(field_name, input_attributes).html_safe
  end
end