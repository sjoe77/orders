module Paginatable
  extend ActiveSupport::Concern


  class PaginationResult
    attr_reader :current_page, :per_page, :relation

    def initialize(relation:, page:, per_page:)
      @relation = relation
      @current_page = page
      @per_page = per_page
    end

    def records
      @records ||= relation.limit(per_page).offset(offset_value)
    end

    def total_count
      @total_count ||= calculate_total_count
    end

    def total_pages
      @total_pages ||= (total_count.to_f / per_page).ceil
    end

    def offset_value
      (current_page - 1) * per_page
    end

    def limit_value
      per_page
    end

    def first?
      current_page == 1
    end

    def last?
      current_page >= total_pages
    end

    def prev_page
      return nil if first?
      current_page - 1
    end

    def next_page
      return nil if last?
      current_page + 1
    end

    def empty?
      records.empty?
    end

    # Performance optimization for large datasets
    def calculate_total_count
      # For performance, we can implement smart counting:
      # - Use cached counts for large tables
      # - Use estimated counts from pg_stats for very large tables
      # - Fall back to regular COUNT for smaller datasets

      begin
        # Check if this is a complex query (has joins, aggregates, etc.)
        sql_string = relation.respond_to?(:to_sql) ? relation.to_sql : ""

        if sql_string.match?(/JOIN|GROUP BY|HAVING|DISTINCT/i)
          # Complex query - use subquery approach
          ActiveRecord::Base.connection.execute(
            "SELECT COUNT(*) FROM (#{relation.limit(nil).offset(nil).to_sql}) AS count_query"
          ).first['count'].to_i
        else
          # Simple query - use regular count for now
          relation.count
        end
      rescue => e
        # Fallback to regular count if anything fails
        relation.count
      end
    end

    private

    def get_estimated_count(table_name)
      result = ActiveRecord::Base.connection.execute(
        "SELECT reltuples::bigint AS estimate FROM pg_class WHERE relname = '#{table_name}'"
      ).first

      result ? result['estimate'].to_i : 0
    rescue
      # Fallback to regular count if estimate fails
      relation.count
    end

    def needs_exact_count?
      # You can add logic here to determine when exact counts are needed
      # For example, for admin interfaces, reports, etc.
      false
    end
  end
end