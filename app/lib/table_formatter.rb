class TableFormatter
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::DateHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::TranslationHelper

  def format(value, format_type, column_config = {})
    return '' if value.nil?

    case format_type
    when 'currency'
      number_to_currency(value,
        precision: column_config[:precision] || 2,
        locale: I18n.locale,
        unit: column_config[:currency] || I18n.t('number.currency.format.unit')
      )
    when 'decimal'
      number_with_precision(value,
        precision: column_config[:precision] || 2,
        locale: I18n.locale,
        delimiter: I18n.t('number.format.delimiter'),
        separator: I18n.t('number.format.separator')
      )
    when 'integer'
      number_with_delimiter(value, locale: I18n.locale)
    when 'percentage'
      number_to_percentage(value,
        precision: column_config[:precision] || 1,
        locale: I18n.locale
      )
    when 'datetime'
      return value.to_s unless value.respond_to?(:strftime)
      value.strftime('%m/%d/%Y %I:%M %p')
    when 'date'
      return value.to_s unless value.respond_to?(:strftime)
      value.strftime('%m/%d/%Y')
    when 'time'
      return value.to_s unless value.respond_to?(:strftime)
      value.strftime('%I:%M %p')
    when 'boolean'
      format_boolean(value)
    when 'truncate'
      truncate(value, length: column_config[:length] || 50)
    when 'email'
      format_email(value)
    when 'phone'
      format_phone(value)
    when 'country_code'
      format_country_code(value)
    when 'weight'
      format_weight(value, column_config)
    else
      value.to_s
    end
  end

  def column_alignment_class(format_type)
    case format_type
    when 'currency', 'decimal', 'integer', 'percentage', 'weight'
      'text-end'
    when 'boolean'
      'text-center'
    else
      'text-start'
    end
  end

  private

  def format_boolean(value)
    icon_class = value ? 'bi-check-circle-fill text-success' : 'bi-x-circle-fill text-muted'
    title_text = value ? I18n.t('common.yes') : I18n.t('common.no')
    content_tag(:i, '', class: icon_class, title: title_text)
  end

  def format_email(value)
    return unless value.present?
    mail_to(value, value, class: 'link')
  end

  def format_phone(value)
    return unless value.present?
    phone_to(value, value, class: 'link')
  end

  def format_country_code(value)
    country_name = ISO3166::Country[value]&.name || value
    content_tag(:span, country_name, title: value)
  end

  def format_weight(value, column_config)
    unit = column_config[:unit] || 'kg'
    "#{number_with_precision(value, precision: 2)} #{unit}"
  end
end