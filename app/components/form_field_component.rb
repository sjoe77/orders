class FormFieldComponent < ViewComponent::Base
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::FormTagHelper
  include ActionView::Helpers::TextHelper

  def initialize(
    form:,
    field_name:,
    field_type: :text,
    label: nil,
    required: false,
    readonly: false,
    visible: true,
    col: nil,
    placeholder: nil,
    help_text: nil,
    **options
  )
    @form = form
    @field_name = field_name
    @field_type = field_type
    @label = label
    @required = required
    @readonly = readonly
    @visible = visible
    @col = col
    @placeholder = placeholder
    @help_text = help_text
    @options = options
  end

  private

  attr_reader :form, :field_name, :field_type, :label, :required, :readonly,
              :visible, :col, :placeholder, :help_text, :options

  def field_id
    "#{form.object_name}_#{field_name}"
  end

  def field_value
    form.object.public_send(field_name) if form.object.respond_to?(field_name)
  end

  def field_errors
    return [] unless form.object.respond_to?(:errors)
    form.object.errors[field_name]
  end

  def has_errors?
    field_errors.any?
  end

  def validation_class
    return '' unless form.object.respond_to?(:errors)
    has_errors? ? 'is-invalid' : ''
  end

  def input_classes
    classes = ['form-control', 'form-control-sm', validation_class].compact
    classes << options[:class] if options[:class]
    classes.join(' ')
  end

  def wrapper_classes
    classes = []
    classes << 'd-none' unless visible
    classes.join(' ')
  end

  def input_attributes
    attrs = {
      id: field_id,
      class: input_classes,
      required: required,
      readonly: readonly
    }

    attrs[:placeholder] = placeholder if placeholder
    attrs[:'aria-describedby'] = describedby_ids if describedby_ids.present?

    # Only include recognized HTML input attributes
    html_options = options.slice(:step, :min, :max, :rows, :data, :title, :tabindex)
    attrs.merge(html_options)
  end

  def describedby_ids
    ids = []
    ids << "#{field_id}_help" if help_text
    ids << "#{field_id}_feedback" if has_errors?
    ids.any? ? ids.join(' ') : nil
  end

  def label_text
    label || field_name.to_s.humanize
  end

  def required_indicator
    content_tag(:span, ' *', class: 'text-danger') if required
  end
end