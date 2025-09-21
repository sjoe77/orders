class TableComponent < ViewComponent::Base
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::UrlHelper

  def initialize(collection:, config:, current_params: {}, formatter: TableFormatter.new, paginator: PaginationRenderer.new)
    @collection = collection
    @config = config
    @current_params = current_params
    @formatter = formatter
    @paginator = paginator
  end

privateR

  attr_reader :collection, :config, :current_params, :formatter, :paginator

  def table_id
    "table_content"
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
    columns.size + aggregate_columns.size
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
    paginator.render_links(collection, current_params)
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

    link_to current_params.merge(sort: field, direction: new_direction),
            class: "text-decoration-none d-flex align-items-center #{link_class}",
            data: { turbo_frame: 'table_content' } do
      content_tag(:span, label, class: 'me-1') +
      content_tag(:i, '', class: "bi #{icon_class}")
    end
  end
end