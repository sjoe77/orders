class FormComponent < ViewComponent::Base
  include ActionView::Helpers::FormHelper
  include ActionView::Helpers::TagHelper

  def initialize(model:, url: nil, method: :patch, local: true, **options)
    @model = model
    @url = url
    @method = method
    @local = local
    @options = options
  end

  def call
    form_with(model: model, url: url, method: method, local: local, **form_options) do |form|
      @form = form
      content_tag(:div, class: 'container-fluid px-0') do
        content_tag(:div, class: 'row g-2') do
          content
        end
      end
    end
  end

  def input_field(field_name, **options)
    component = TextFieldComponent.new(form: form, field_name: field_name, **options)
    component.render_in(self)
  end

  def text_area_field(field_name, **options)
    component = TextAreaComponent.new(form: form, field_name: field_name, **options)
    component.render_in(self)
  end

  def email_input(field_name, **options)
    component = EmailFieldComponent.new(form: form, field_name: field_name, **options)
    component.render_in(self)
  end

  def number_input(field_name, **options)
    component = NumberFieldComponent.new(form: form, field_name: field_name, **options)
    component.render_in(self)
  end

  def phone_input(field_name, **options)
    component = TelephoneFieldComponent.new(form: form, field_name: field_name, **options)
    component.render_in(self)
  end

  def select_input(field_name, options: [], **component_options)
    component = SelectComponent.new(form: form, field_name: field_name, options: options, **component_options)
    component.render_in(self)
  end

  def checkbox_input(field_name, **options)
    component = CheckboxComponent.new(form: form, field_name: field_name, **options)
    component.render_in(self)
  end

  def row(&block)
    content_tag(:div, class: 'row g-2', &block)
  end

  def col(size = 12, md: nil, lg: nil, &block)
    classes = ["col-#{size}"]
    classes << "col-md-#{md}" if md
    classes << "col-lg-#{lg}" if lg

    content_tag(:div, class: classes.join(' '), &block)
  end

  def section(title = nil, &block)
    content_tag(:div, class: 'col-12') do
      section_content = ''

      if title
        section_content += content_tag(:h6, title, class: 'mb-2 text-muted')
      end

      section_content += content_tag(:div, class: 'row g-2', &block)
      section_content.html_safe
    end
  end

  def submit_button(label = nil, **options)
    label ||= model.persisted? ? 'Update' : 'Create'
    classes = ['btn', 'btn-primary', 'btn-sm']
    classes << options[:class] if options[:class]

    form.submit label, class: classes.join(' '), **options.except(:class)
  end

  def hidden_input(field_name, **options)
    form.hidden_field field_name, **options
  end

  private

  attr_reader :model, :url, :method, :local, :options, :form

  def form_options
    {
      class: 'needs-validation',
      novalidate: true
    }.merge(options)
  end
end