class CheckboxComponent < FormFieldComponent
  def initialize(form:, field_name:, **options)
    super(form: form, field_name: field_name, field_type: :checkbox, **options)
  end

  private

  def content
    content_tag(:div, class: 'form-check d-flex align-items-center') do
      form.check_box(field_name, checkbox_attributes) +
      content_tag(:label, label_text, for: field_id, class: 'form-check-label small ms-1')
    end
  end

  def checkbox_attributes
    {
      id: field_id,
      class: checkbox_classes,
      required: required,
      readonly: readonly
    }.merge(options.except(:class))
  end

  def checkbox_classes
    classes = ['form-check-input', validation_class].compact
    classes << options[:class] if options[:class]
    classes.join(' ')
  end

  def wrapper_classes
    classes = []
    classes << 'd-none' unless visible
    classes.join(' ')
  end
end