class Product < ApplicationRecord
  has_many :product_categories, dependent: :destroy
  has_many :categories, through: :product_categories
  has_many :product_tags, dependent: :destroy
  has_many :tags, through: :product_tags
  has_many :inventory_items, dependent: :destroy
  has_many :order_line_items, dependent: :restrict_with_error

  validates :product_key_nm, presence: true, uniqueness: true
  validates :sku_nm, presence: true, uniqueness: true
  validates :name_nm, presence: true
  validates :unit_price_amt, presence: true, numericality: { greater_than: 0 }
  validates :cost_amt, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validates :weight_num, numericality: { greater_than: 0 }, allow_blank: true

  before_validation :generate_sku, on: :create

  scope :active, -> { where(active_flag: true) }
  scope :by_name, ->(name) { where("name_nm ILIKE ?", "%#{name}%") }
  scope :by_category, ->(category_id) { joins(:categories).where(categories: { id: category_id }) }
  scope :by_tag, ->(tag_id) { joins(:tags).where(tags: { id: tag_id }) }

  def dimensions
    return {} unless dimensions_json.present?

    JSON.parse(dimensions_json)
  rescue JSON::ParserError
    {}
  end

  def dimensions=(value)
    self.dimensions_json = value.is_a?(String) ? value : value.to_json
  end

  def total_inventory
    inventory_items.sum(:quantity_on_hand_cnt)
  end

  def available_inventory
    inventory_items.sum('quantity_on_hand_cnt - reserved_quantity_cnt')
  end

  private

  def generate_sku
    return if sku_nm.present?

    last_product = Product.order(:sku_nm).last
    next_num = last_product ? last_product.sku_nm.gsub(/\D/, '').to_i + 1 : 1
    self.sku_nm = "SKU-#{next_num.to_s.rjust(6, '0')}"
  end
end
