module TableHelper


  def format_table_value(value, format_type, column_config = {})
    return '' if value.nil?

    case format_type
    when 'currency'
      # Use Rails i18n currency formatting with proper locale
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
      l(value, format: column_config[:format] || :long)
    when 'date'
      l(value.to_date, format: column_config[:format] || :long)
    when 'time'
      l(value, format: column_config[:format] || :time)
    when 'boolean'
      icon_class = value ? 'bi-check-circle-fill text-success' : 'bi-x-circle-fill text-muted'
      content_tag(:i, '', class: icon_class, title: value ? t('common.yes') : t('common.no'))
    when 'truncate'
      truncate(value, length: column_config[:length] || 50)
    when 'email'
      mail_to(value, value, class: 'link') if value.present?
    when 'phone'
      phone_to(value, value, class: 'link') if value.present?
    when 'country_code'
      # ISO 3166-1 alpha-2 country codes
      country_name = ISO3166::Country[value]&.name || value
      content_tag(:span, country_name, title: value)
    when 'weight'
      # Weight with proper unit formatting
      "#{number_with_precision(value, precision: 2)} #{column_config[:unit] || 'kg'}"
    else
      value.to_s
    end
  end

  def table_sort_link(field, label, current_params = {})
    current_sort = current_params[:sort]
    current_direction = current_params[:direction] || 'asc'

    if current_sort == field.to_s
      new_direction = current_direction == 'asc' ? 'desc' : 'asc'
      icon_class = current_direction == 'asc' ? 'bi-arrow-up' : 'bi-arrow-down'
      link_class = 'table-sort-active'
    else
      new_direction = 'asc'
      icon_class = 'bi-arrow-down-up'
      link_class = ''
    end

    link_to current_params.merge(sort: field, direction: new_direction),
            class: "text-decoration-none d-flex align-items-center #{link_class}",
            data: { turbo_frame: 'table_content' } do
      content_tag(:span, label, class: 'me-1') +
      content_tag(:i, '', class: "bi #{icon_class}")
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

  def table_action_buttons(record, config)
    actions = config[:actions] || []
    content = ''.html_safe

    actions.each do |action|
      case action
      when 'edit'
        content += link_to edit_polymorphic_path(record),
          class: 'btn btn-sm btn-outline-primary me-1',
          title: t('common.edit'),
          data: { turbo_frame: '_top' } do
          content_tag(:i, '', class: 'bi bi-pencil')
        end
      when 'delete'
        content += link_to polymorphic_path(record),
          method: :delete,
          class: 'btn btn-sm btn-outline-danger me-1',
          title: t('common.delete'),
          confirm: t('common.confirm_delete'),
          data: { turbo_frame: '_top' } do
          content_tag(:i, '', class: 'bi bi-trash')
        end
      when 'view'
        content += link_to polymorphic_path(record),
          class: 'btn btn-sm btn-outline-secondary me-1',
          title: t('common.view'),
          data: { turbo_frame: '_top' } do
          content_tag(:i, '', class: 'bi bi-eye')
        end
      end
    end

    content
  end

  def paginate_with_beer_css(pagination_result, url_params = {})
    content_tag(:div, class: 'grid') do
      content_tag(:div, class: 's12 m6 left-align') do
        pagination_info(pagination_result)
      end +
      content_tag(:div, class: 's12 m6 right-align') do
        paginate_collection(pagination_result, url_params)
      end
    end
  end

  def export_buttons(entity_name, current_params = {})
    content_tag(:div, class: 'export-buttons') do
      link_to current_params.merge(format: :csv),
        class: 'circle secondary',
        title: t('table.export.csv'),
        data: { turbo: false } do
        content_tag(:i, 'download')
      end
    end
  end

  def paginate_collection(pagination_result, url_params = {})
    return '' if pagination_result.total_pages <= 1

    content_tag(:nav, 'aria-label': 'Table pagination') do
      content_tag(:ul, class: 'pagination pagination-sm justify-content-end mb-0') do
        items = []

        # Previous page
        if pagination_result.prev_page
          items << content_tag(:li, class: 'page-item') do
            link_to url_params.merge(page: pagination_result.prev_page),
              class: 'page-link',
              data: { turbo_frame: 'table_content' },
              'aria-label': 'Previous' do
              content_tag(:i, '', class: 'bi bi-chevron-left')
            end
          end
        else
          items << content_tag(:li, class: 'page-item disabled') do
            content_tag(:span, class: 'page-link') do
              content_tag(:i, '', class: 'bi bi-chevron-left')
            end
          end
        end

        # Page info
        items << content_tag(:li, class: 'page-item disabled') do
          content_tag(:span, class: 'page-link') do
            "#{pagination_result.current_page} of #{pagination_result.total_pages}"
          end
        end

        # Next page
        if pagination_result.next_page
          items << content_tag(:li, class: 'page-item') do
            link_to url_params.merge(page: pagination_result.next_page),
              class: 'page-link',
              data: { turbo_frame: 'table_content' },
              'aria-label': 'Next' do
              content_tag(:i, '', class: 'bi bi-chevron-right')
            end
          end
        else
          items << content_tag(:li, class: 'page-item disabled') do
            content_tag(:span, class: 'page-link') do
              content_tag(:i, '', class: 'bi bi-chevron-right')
            end
          end
        end

        safe_join(items)
      end
    end
  end

  def pagination_info(pagination_result)
    return '' if pagination_result.empty?

    from = pagination_result.offset_value + 1
    to = [pagination_result.offset_value + pagination_result.limit_value, pagination_result.total_count].min
    total = pagination_result.total_count

    t('common.showing_entries', from: from, to: to, total: total)
  end
end