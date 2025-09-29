require 'uri'
require 'cgi'

class PaginationRenderer
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::OutputSafetyHelper
  include Rails.application.routes.url_helpers

  def render_links(pagination_result, url_params = {}, config = {})
    return '' if pagination_result.total_pages <= 1

    content_tag(:nav, 'aria-label': 'Table pagination') do
      content_tag(:ul, class: 'pagination pagination-sm justify-content-end mb-0') do
        items = []

        # Previous page
        items << previous_page_item(pagination_result, url_params, config)

        # Page info
        items << page_info_item(pagination_result)

        # Next page
        items << next_page_item(pagination_result, url_params, config)

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

  def previous_page_item(pagination_result, url_params, config = {})
    if pagination_result.prev_page
      content_tag(:li, class: 'page-item') do
        link_to build_url_with_params(url_params.merge(page: pagination_result.prev_page), config),
          class: 'page-link',
          data: { turbo_frame: config[:frame_id] || 'table_content' },
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

  def next_page_item(pagination_result, url_params, config = {})
    if pagination_result.next_page
      content_tag(:li, class: 'page-item') do
        link_to build_url_with_params(url_params.merge(page: pagination_result.next_page), config),
          class: 'page-link',
          data: { turbo_frame: config[:frame_id] || 'table_content' },
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

  def build_url_with_params(params, config = {})
    # Clean params - remove controller/action/format and other Rails internals
    clean_params = params.except(:controller, :action, :format, :authenticity_token, :commit)

    if config[:base_url]
      # For relationship contexts, build URL using Rails url_for
      # Parse the base_url to get the path and merge with clean params
      base_uri = URI.parse(config[:base_url])
      base_params = base_uri.query ? CGI.parse(base_uri.query).transform_values(&:first) : {}

      # Remove path-embedded parameters to avoid redundancy
      # For URLs like /categories/18/products, remove id=18 from query params
      filtered_params = remove_path_embedded_params(clean_params.stringify_keys, base_uri.path)
      merged_params = base_params.merge(filtered_params)

      # Build clean URL with merged parameters
      query_string = merged_params.to_query
      query_string.present? ? "#{base_uri.path}?#{query_string}" : base_uri.path
    else
      # For main tables, use current path with clean params
      query_string = clean_params.to_query
      query_string.present? ? "?#{query_string}" : ""
    end
  end

  def remove_path_embedded_params(params, path)
    # Extract numeric IDs from path segments like /categories/18/products
    path_segments = path.split('/').reject(&:empty?)
    embedded_ids = path_segments.select { |segment| segment.match?(/^\d+$/) }

    # Remove id parameter if it matches any embedded ID in the path
    if params['id'] && embedded_ids.include?(params['id'])
      params.except('id')
    else
      params
    end
  end
end