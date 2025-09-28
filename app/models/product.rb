class Product < ApplicationRecord
  include TableConfigurable
  include Paginatable

  has_paper_trail meta: { audit_transaction_id: :paper_trail_audit_transaction_id }
  attr_accessor :audit_reason, :pending_changes

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

  configure_table do
    column :sku_nm, format: 'string', sortable: true
    column :name_nm, format: 'string', sortable: true
    column :unit_price_amt, format: 'currency', sortable: true
    column :cost_amt, format: 'currency', sortable: true
    column :weight_num, format: 'decimal', sortable: true
    column :active_flag, format: 'boolean', sortable: true

    # Search configuration
    searchable :name_nm, :sku_nm, :description_txt

    # Table configuration
    per_page_options 10, 25, 50
    default_per_page 10
    default_sort field: :name_nm, direction: :asc
  end

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

  def paper_trail_audit_transaction_id
    PaperTrail.request.controller_info[:audit_transaction_id] if PaperTrail.request.controller_info
  end

  # Define audit scope for this entity - includes product and its categories/tags if needed
  def self.audit_scope(product)
    # For now, just return the product's own audit transactions
    # Could be extended to include related ProductCategory records if needed
    AuditTransaction.where(item: product)
  end

  # Explicit M:M relationship setters
  def category_ids=(ids)
    apply_mm_relationship_changes(:categories, :product_categories, :category_id, ids)
  end

  def tag_ids=(ids)
    apply_mm_relationship_changes(:tags, :product_tags, :tag_id, ids)
  end

  private

  def apply_mm_relationship_changes(relationship_name, join_table_association, foreign_key_column, new_ids)
    # Convert to strings for consistent comparison
    new_ids = Array(new_ids).map(&:to_s).reject(&:blank?)
    current_ids = self.send(relationship_name).pluck(:id).map(&:to_s)

    # Calculate what needs to be changed
    to_unlink = current_ids - new_ids  # Remove these relationship links
    to_link = new_ids - current_ids    # Add these relationship links

    # Only unlink relationships that were removed
    if to_unlink.any?
      self.send(join_table_association).where(foreign_key_column => to_unlink).destroy_all
    end

    # Only link relationships that were added
    if to_link.any?
      to_link.each do |related_id|
        self.send(join_table_association).create!(foreign_key_column => related_id)
      end
    end

    Rails.logger.info "M:M changes applied to #{relationship_name}: unlinked #{to_unlink.length}, linked #{to_link.length}"
  end

  def generate_sku
    return if sku_nm.present?

    last_product = Product.order(:sku_nm).last
    next_num = last_product ? last_product.sku_nm.gsub(/\D/, '').to_i + 1 : 1
    self.sku_nm = "SKU-#{next_num.to_s.rjust(6, '0')}"
  end
end
