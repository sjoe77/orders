class TableComponent < ViewComponent::Base
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::UrlHelper

  def initialize(collection:, config:, current_params: {}, formatter: TableFormatter.new, paginator: PaginationRenderer.new, show_checkboxes: false, checkbox_options: {})
    @collection = collection
    @config = config
    @current_params = current_params
    @formatter = formatter
    @paginator = paginator
    @show_checkboxes = show_checkboxes
    @checkbox_options = checkbox_options
  end

private

  attr_reader :collection, :config, :current_params, :formatter, :paginator, :show_checkboxes, :checkbox_options

  def table_id
    config[:frame_id] || "table_content"
  end

  def columns
    config[:columns] || {}
  end

  def aggregate_columns
    config[:aggregate_columns] || {}
  end

  def empty_message
    I18n.t('common.no_records')
  end

  def total_columns
    base_columns = columns.size + aggregate_columns.size
    delete_checkbox_column = config[:show_delete_checkboxes] ? 1 : 0
    select_checkbox_column = (show_checkboxes || config[:show_checkboxes]) ? 1 : 0
    base_columns + delete_checkbox_column + select_checkbox_column
  end

  def format_table_value(value, format_type, column_config = {})
    formatter.format(value, format_type, column_config)
  end

  def column_alignment_class(format_type)
    formatter.column_alignment_class(format_type)
  end

  def pagination_info
    paginator.render_info(collection)
  end

  def pagination_links
    paginator.render_links(collection, current_params, config)
  end

  def table_sort_link(field, label)
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

    # Convert ActionController::Parameters to hash before merging
    params_hash = current_params.respond_to?(:to_unsafe_h) ? current_params.to_unsafe_h : current_params

    # Use base_url from config for relationship contexts, otherwise current path
    sort_params = params_hash.merge(sort: field, direction: new_direction)
    if config[:base_url]
      # For relationship contexts, build URL with base_url and params
      sort_url = "#{config[:base_url]}?#{sort_params.to_query}"
    else
      # For main tables, use current path with params
      sort_url = sort_params
    end

    # Use frame_id from config if available, otherwise default to table_content
    frame_target = config[:frame_id] || 'table_content'

    link_to sort_url,
            class: "text-decoration-none d-flex align-items-center #{link_class}",
            data: {
              turbo_frame: frame_target,
              turbo_preload: "0"
            },
            rel: "" do
      content_tag(:span, label, class: 'me-1') +
      content_tag(:i, '', class: "bi #{icon_class}")
    end
  end
end