module TableConfigurable
  extend ActiveSupport::Concern

  class_methods do
    def table_config
      @table_config ||= {}
    end

    def configure_table(&block)
      config = TableConfiguration.new
      config.instance_eval(&block)
      @table_config = config.to_hash
    end

    def paginated_results(params = {})
      # Apply filters first
      query = apply_table_filters(params)

      # Apply aggregate columns if needed
      query = query.with_aggregate_columns(params) if table_config[:aggregate_columns]&.any?

      # Apply sorting
      query = query.apply_table_sorting(params)

      # Apply pagination
      paginate_relation(
        query,
        page: params[:page],
        per_page: params[:per_page] || table_config[:default_per_page] || 25
      )
    end

    # Support for aggregate columns that require joins or calculations
    def with_aggregate_columns(params = {})
      query = self
      config = table_config

      if config[:aggregate_columns]&.any?
        config[:aggregate_columns].each do |col_name, col_config|
          case col_config[:type]
          when 'count'
            # Example: customers.pending_orders_count
            query = query.left_joins(col_config[:association])
                         .group("#{table_name}.id")
                         .select("#{table_name}.*, COUNT(#{col_config[:association]}.id) as #{col_name}")

            # Support filtering by aggregate
            if params[:"#{col_name}_min"].present?
              query = query.having("COUNT(#{col_config[:association]}.id) >= ?", params[:"#{col_name}_min"])
            end

          when 'sum'
            # Example: customers.total_order_value
            query = query.left_joins(col_config[:association])
                         .group("#{table_name}.id")
                         .select("#{table_name}.*, COALESCE(SUM(#{col_config[:field]}), 0) as #{col_name}")

          when 'latest'
            # Example: customers.last_order_date
            query = query.left_joins(col_config[:association])
                         .group("#{table_name}.id")
                         .select("#{table_name}.*, MAX(#{col_config[:field]}) as #{col_name}")
          end
        end
      end

      query
    end

    def apply_table_filters(params = {})
      query = all
      config = table_config

      # Apply search filter
      if params[:search].present? && config[:searchable_columns]
        search_conditions = config[:searchable_columns].map do |column|
          "#{column} ILIKE ?"
        end.join(' OR ')

        search_params = Array.new(config[:searchable_columns].length, "%#{params[:search]}%")
        query = query.where(search_conditions, *search_params)
      end

      # Apply column filters
      config[:columns]&.each do |column_name, column_config|
        filter_param = params[:"filter_#{column_name}"]
        next unless filter_param.present?

        case column_config[:filter_type]
        when 'select'
          query = query.where(column_name => filter_param) unless filter_param == 'all'
        when 'boolean'
          query = query.where(column_name => filter_param == 'true') unless filter_param == 'all'
        when 'date_range'
          if params[:"#{column_name}_from"].present?
            query = query.where("#{column_name} >= ?", Date.parse(params[:"#{column_name}_from"]))
          end
          if params[:"#{column_name}_to"].present?
            query = query.where("#{column_name} <= ?", Date.parse(params[:"#{column_name}_to"]))
          end
        end
      end

      query
    end

    def paginate_relation(relation, page: 1, per_page: 25)
      page = [page.to_i, 1].max
      per_page = [[per_page.to_i, 100].min, 5].max

      Paginatable::PaginationResult.new(
        relation: relation,
        page: page,
        per_page: per_page
      )
    end

    def apply_table_sorting(params = {})
      return all unless params[:sort].present?

      config = table_config
      sort_column = params[:sort].to_s
      direction = params[:direction] == 'desc' ? 'desc' : 'asc'

      # Check if it's a sortable column (try both string and symbol keys)
      column_config = config[:columns]&.[](sort_column.to_sym) || config[:columns]&.[](sort_column)
      return all unless column_config&.[](:sortable)

      # Handle aggregate column sorting
      if config[:aggregate_columns]&.[](sort_column.to_sym) || config[:aggregate_columns]&.[](sort_column)
        # Aggregate columns are already selected in with_aggregate_columns
        order("#{sort_column} #{direction}")
      else
        # Regular column sorting
        order("#{sort_column} #{direction}")
      end
    end
  end

  private

  class TableConfiguration
    def initialize
      @config = {
        columns: {},
        aggregate_columns: {},
        searchable_columns: [],
        actions: ['view', 'edit', 'delete'],
        per_page_options: [25, 50, 100],
        default_per_page: 25,
        default_sort: { field: :id, direction: :asc }
      }
    end

    def column(name, **options)
      @config[:columns][name] = options
    end

    def aggregate_column(name, **options)
      @config[:aggregate_columns][name] = options
    end

    def searchable(*columns)
      @config[:searchable_columns] = columns
    end

    def actions(*action_list)
      @config[:actions] = action_list
    end

    def per_page_options(*options)
      @config[:per_page_options] = options
    end

    def default_per_page(count)
      @config[:default_per_page] = count
    end

    def default_sort(field:, direction: :asc)
      @config[:default_sort] = { field: field, direction: direction }
    end

    def to_hash
      @config
    end
  end
end