module PaginationHelper
  def paginate_collection(pagination_result, url_params = {})
    return '' if pagination_result.total_pages <= 1

    content_tag(:nav, class: 'pagination', role: 'navigation',
                'aria-label': t('views.pagination.aria_label')) do

      pagination_links(pagination_result, url_params)
    end
  end

  def pagination_info(pagination_result)
    return '' if pagination_result.empty?

    from = pagination_result.offset_value + 1
    to = [pagination_result.offset_value + pagination_result.per_page,
          pagination_result.total_count].min

    content_tag(:span,
      t('common.showing_entries',
        from: number_with_delimiter(from),
        to: number_with_delimiter(to),
        total: number_with_delimiter(pagination_result.total_count)
      ),
      class: 'pagination-info'
    )
  end

  def per_page_selector(current_per_page, url_params = {}, options = [25, 50, 100])
    content_tag(:div, class: 'per-page-selector') do
      content_tag(:div, class: 'field') do
        select_tag(:per_page,
          options_for_select(
            options.map { |n| [t('common.per_page_option', count: n), n] },
            current_per_page
          ),
          onchange: 'this.form.submit()',
          'data-turbo-frame': 'table_content'
        ) +
        content_tag(:label, t('common.per_page'))
      end
    end
  end

  private

  def pagination_links(pagination_result, url_params)
    links = []

    # Previous button
    unless pagination_result.first?
      links << link_to(
        url_for(url_params.merge(page: pagination_result.prev_page)),
        class: 'button transparent',
        'data-turbo-frame': 'table_content',
        'aria-label': t('views.pagination.previous')
      ) do
        content_tag(:i, 'chevron_left')
      end
    else
      links << content_tag(:button, class: 'button transparent', disabled: true) do
        content_tag(:i, 'chevron_left')
      end
    end

    # Page info
    links << content_tag(:span, class: 'page-info') do
      t('views.pagination.page_of_pages',
        current: number_with_delimiter(pagination_result.current_page),
        total: number_with_delimiter(pagination_result.total_pages)
      )
    end

    # Next button
    unless pagination_result.last?
      links << link_to(
        url_for(url_params.merge(page: pagination_result.next_page)),
        class: 'button transparent',
        'data-turbo-frame': 'table_content',
        'aria-label': t('views.pagination.next')
      ) do
        content_tag(:i, 'chevron_right')
      end
    else
      links << content_tag(:button, class: 'button transparent', disabled: true) do
        content_tag(:i, 'chevron_right')
      end
    end

    safe_join(links, ' ')
  end
end