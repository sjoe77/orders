class RelationshipPaginationRenderer < PaginationRenderer
  def initialize(base_url: nil, table_id: nil)
    @base_url = base_url
    @table_id = table_id
  end

  private

  attr_reader :base_url, :table_id

  def build_url_with_params(params)
    if base_url
      # Convert to hash if it's ActionController::Parameters to avoid unpermitted parameters error
      params_hash = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params
      "#{base_url}?#{params_hash.to_query}"
    else
      super
    end
  end

  def previous_page_item(pagination_result, url_params)
    if pagination_result.prev_page
      content_tag(:li, class: 'page-item') do
        link_to build_url_with_params(url_params.merge(page: pagination_result.prev_page)),
          class: 'page-link',
          data: { turbo_frame: table_id },
          'aria-label': 'Previous' do
          content_tag(:i, '', class: 'bi bi-chevron-left')
        end
      end
    else
      content_tag(:li, class: 'page-item disabled') do
        content_tag(:span, class: 'page-link', 'aria-label': 'Previous') do
          content_tag(:i, '', class: 'bi bi-chevron-left')
        end
      end
    end
  end

  def next_page_item(pagination_result, url_params)
    if pagination_result.next_page
      content_tag(:li, class: 'page-item') do
        link_to build_url_with_params(url_params.merge(page: pagination_result.next_page)),
          class: 'page-link',
          data: { turbo_frame: table_id },
          'aria-label': 'Next' do
          content_tag(:i, '', class: 'bi bi-chevron-right')
        end
      end
    else
      content_tag(:li, class: 'page-item disabled') do
        content_tag(:span, class: 'page-link', 'aria-label': 'Next') do
          content_tag(:i, '', class: 'bi bi-chevron-right')
        end
      end
    end
  end
end