class RelationshipTableComponent < TableComponent
  def initialize(title:, records:, per_page: 10, current_params: {}, actions: {}, base_url: nil, **options)
    @title = title
    @actions = actions
    @relationship_options = options
    @base_url = base_url

    # Convert records to paginated collection like TableComponent expects
    paginated_records = paginate_records(records, per_page, current_params)
    config = build_table_config(records)

    # Initialize parent with proper TableComponent interface
    super(
      collection: paginated_records,
      config: config,
      current_params: current_params,
      formatter: TableFormatter.new,
      paginator: RelationshipPaginationRenderer.new(base_url: base_url, table_id: table_id)
    )
  end

  private

  attr_reader :title, :actions, :relationship_options, :base_url

  def paginate_records(records, per_page, current_params)
    page = (current_params[:page] || 1).to_i
    sort_field = current_params[:sort]
    sort_direction = current_params[:direction] || 'asc'

    # Apply sorting if specified
    if sort_field.present? && records.respond_to?(:order)
      # Ensure the sort field exists on the model
      if records.klass.column_names.include?(sort_field.to_s)
        records = records.order("#{sort_field} #{sort_direction}")
      end
    end

    # Create a simple paginated wrapper that mimics Kaminari interface
    total_count = records.count
    offset = (page - 1) * per_page
    paginated_data = records.offset(offset).limit(per_page)

    RelationshipPaginatedCollection.new(
      records: paginated_data,
      current_page: page,
      per_page: per_page,
      total_count: total_count
    )
  end

  def build_table_config(records)
    entity_name = infer_entity_name(records)

    {
      entity_name: entity_name,
      columns: get_table_columns(records),
      aggregate_columns: {}
    }
  end

  def get_table_columns(records)
    return {} unless records.respond_to?(:klass) && records.klass.respond_to?(:table_config)

    config = records.klass.table_config
    return {} unless config[:columns]

    # Use the existing table_config columns with same format as TableComponent
    config[:columns]
  end

  def infer_entity_name(records)
    return 'record' unless records.respond_to?(:klass)
    records.klass.model_name.singular.downcase
  end

  def table_id
    @table_id ||= "relationship_table_#{SecureRandom.hex(4)}"
  end

  # Override parent's table_sort_link to target the correct Turbo Frame
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

    # Build URL - use base_url if provided, otherwise current params
    if base_url
      # Convert ActionController::Parameters to hash to avoid unpermitted parameters error
      params_hash = current_params.to_unsafe_h.merge(sort: field, direction: new_direction)
      url = "#{base_url}?#{params_hash.to_query}"
    else
      url = current_params.merge(sort: field, direction: new_direction)
    end

    # Use the relationship table's unique turbo frame ID
    link_to url,
            class: "text-decoration-none d-flex align-items-center #{link_class}",
            data: { turbo_frame: table_id } do
      content_tag(:span, label, class: 'me-1') +
      content_tag(:i, '', class: "bi #{icon_class}")
    end
  end

  def show_actions?
    actions.any? { |_, enabled| enabled }
  end

  def can_create?
    actions.fetch(:create, false)
  end

  def can_edit?
    actions.fetch(:edit, false)
  end

  def can_delete?
    actions.fetch(:delete, false)
  end

  def can_view?
    actions.fetch(:view, false)
  end

  def create_action
    actions.dig(:create_action) || {}
  end

  def edit_action
    actions.dig(:edit_action) || {}
  end

  def view_action
    actions.dig(:view_action) || {}
  end

  def delete_action
    actions.dig(:delete_action) || {}
  end

  # Paginated collection wrapper that mimics Kaminari interface for TableComponent
  class RelationshipPaginatedCollection
    attr_reader :records, :current_page, :per_page, :total_count

    def initialize(records:, current_page:, per_page:, total_count:)
      @records = records
      @current_page = current_page
      @per_page = per_page
      @total_count = total_count
    end

    def empty?
      records.empty?
    end

    def total_pages
      (total_count.to_f / per_page).ceil
    end

    def first_page?
      current_page == 1
    end

    def last_page?
      current_page >= total_pages
    end

    def prev_page
      current_page > 1 ? current_page - 1 : nil
    end

    def next_page
      current_page < total_pages ? current_page + 1 : nil
    end

    def offset_value
      (current_page - 1) * per_page
    end

    def limit_value
      per_page
    end

    def count
      total_count
    end
  end
end