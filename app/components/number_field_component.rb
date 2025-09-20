class NumberFieldComponent < FormFieldComponent
  def initialize(form:, field_name:, step: nil, min: nil, max: nil, **options)
    @step = step
    @min = min
    @max = max
    super(form: form, field_name: field_name, field_type: :number, **options)
  end

  private

  attr_reader :step, :min, :max

  def field_value
    value = super
    return value unless value.is_a?(Numeric)

    if value == value.to_i
      value.to_i.to_s
    else
      value.to_s
    end
  end

  def content
    attrs = input_attributes.dup
    attrs[:value] = field_value
    attrs[:step] = step if step
    attrs[:min] = min if min
    attrs[:max] = max if max

    form.number_field field_name, attrs
  end
end