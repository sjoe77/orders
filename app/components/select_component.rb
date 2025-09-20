class SelectComponent < FormFieldComponent
  def initialize(form:, field_name:, options: [], prompt: nil, **component_options)
    @select_options = options
    @prompt = prompt
    super(form: form, field_name: field_name, field_type: :select, **component_options)
  end

  private

  attr_reader :select_options, :prompt

  def content
    form.select field_name, select_options, select_html_options, input_attributes
  end

  def select_html_options
    options = {}
    options[:prompt] = prompt if prompt
    options
  end

  def input_classes
    classes = ['form-select', validation_class].compact
    classes << options[:class] if options[:class]
    classes.join(' ')
  end
end