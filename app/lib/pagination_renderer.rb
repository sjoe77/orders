class PaginationRenderer
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::OutputSafetyHelper
  include Rails.application.routes.url_helpers

  def render_links(pagination_result, url_params = {})
    return '' if pagination_result.total_pages <= 1

    content_tag(:nav, 'aria-label': 'Table pagination') do
      content_tag(:ul, class: 'pagination pagination-sm justify-content-end mb-0') do
        items = []

        # Previous page
        items << previous_page_item(pagination_result, url_params)

        # Page info
        items << page_info_item(pagination_result)

        # Next page
        items << next_page_item(pagination_result, url_params)

        safe_join(items)
      end
    end
  end

  def render_info(pagination_result)
    return '' if pagination_result.empty?

    from = pagination_result.offset_value + 1
    to = [pagination_result.offset_value + pagination_result.limit_value, pagination_result.total_count].min
    total = pagination_result.total_count

    I18n.t('common.showing_entries', from: from, to: to, total: total)
  end

  private

  def previous_page_item(pagination_result, url_params)
    if pagination_result.prev_page
      content_tag(:li, class: 'page-item') do
        link_to build_url_with_params(url_params.merge(page: pagination_result.prev_page)),
          class: 'page-link',
          data: { turbo_frame: 'table_content' },
          'aria-label': 'Previous' do
          content_tag(:i, '', class: 'bi bi-chevron-left')
        end
      end
    else
      content_tag(:li, class: 'page-item disabled') do
        content_tag(:span, class: 'page-link') do
          content_tag(:i, '', class: 'bi bi-chevron-left')
        end
      end
    end
  end

  def page_info_item(pagination_result)
    content_tag(:li, class: 'page-item disabled') do
      content_tag(:span, class: 'page-link') do
        "#{pagination_result.current_page} of #{pagination_result.total_pages}"
      end
    end
  end

  def next_page_item(pagination_result, url_params)
    if pagination_result.next_page
      content_tag(:li, class: 'page-item') do
        link_to build_url_with_params(url_params.merge(page: pagination_result.next_page)),
          class: 'page-link',
          data: { turbo_frame: 'table_content' },
          'aria-label': 'Next' do
          content_tag(:i, '', class: 'bi bi-chevron-right')
        end
      end
    else
      content_tag(:li, class: 'page-item disabled') do
        content_tag(:span, class: 'page-link') do
          content_tag(:i, '', class: 'bi bi-chevron-right')
        end
      end
    end
  end

  def build_url_with_params(params)
    query_string = params.to_query
    current_path = "?" + query_string
    current_path
  end
end