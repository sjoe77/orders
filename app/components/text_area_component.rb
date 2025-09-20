class TextAreaComponent < FormFieldComponent
  def initialize(form:, field_name:, rows: 3, **options)
    @rows = rows
    super(form: form, field_name: field_name, field_type: :textarea, **options)
  end

  private

  attr_reader :rows

  def content
    form.text_area field_name, input_attributes.merge(rows: rows)
  end
end