class TableFilterComponent < ViewComponent::Base
  renders_one :search_field
  renders_many :filter_fields
  renders_one :actions

  def initialize(config:, current_params: {})
    @config = config
    @current_params = current_params
  end

  private

  attr_reader :config, :current_params

  def entity_name
    config[:entity_name]
  end

  def searchable?
    config[:searchable_columns]&.any?
  end

  def search_placeholder
    t('common.search')
  end

  def per_page_options
    config[:per_page_options] || [25, 50, 100]
  end

  def current_per_page
    current_params[:per_page] || config[:default_per_page] || 25
  end

  def new_entity_path
    "/#{entity_name.pluralize}/new"
  end

  def export_csv_path
    current_params.merge(format: :csv)
  end

  def clear_filters_path
    request.path
  end
end