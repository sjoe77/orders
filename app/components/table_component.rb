class TableComponent < ViewComponent::Base
  renders_one :filters
  renders_one :header
  renders_many :rows
  renders_one :pagination

  def initialize(collection:, config:, current_params: {})
    @collection = collection
    @config = config
    @current_params = current_params
  end

  private

  attr_reader :collection, :config, :current_params

  def table_id
    "table_content"
  end

  def columns
    config[:columns] || {}
  end

  def aggregate_columns
    config[:aggregate_columns] || {}
  end

  def actions_enabled?
    config[:actions]&.any?
  end

  def empty_message
    t('common.no_records')
  end

  def total_columns
    columns.size + aggregate_columns.size
  end
end