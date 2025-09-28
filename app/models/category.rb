class Category < ApplicationRecord
  include TableConfigurable
  include Paginatable

  has_paper_trail meta: { audit_transaction_id: :paper_trail_audit_transaction_id }
  attr_accessor :audit_reason

  has_many :product_categories, dependent: :destroy
  has_many :products, through: :product_categories
  belongs_to :parent_category, class_name: 'Category', optional: true
  has_many :subcategories, class_name: 'Category', foreign_key: 'parent_category_id'

  validates :name_nm, presence: true, uniqueness: true
  validates :display_order_num, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(active_flag: true) }
  scope :root_categories, -> { where(parent_category_id: nil) }
  scope :ordered, -> { order(:display_order_num, :name_nm) }

  configure_table do
    column :name_nm, format: 'string', sortable: true
    column :description_txt, format: 'string', sortable: false
    column :display_order_num, format: 'integer', sortable: true
    column :active_flag, format: 'boolean', sortable: true

    # Search configuration
    searchable :name_nm, :description_txt

    # Table configuration
    per_page_options 10, 25, 50
    default_per_page 10
    default_sort field: :display_order_num, direction: :asc
  end

  def hierarchical_name
    return name_nm unless parent_category

    "#{parent_category.hierarchical_name} > #{name_nm}"
  end

  def paper_trail_audit_transaction_id
    PaperTrail.request.controller_info[:audit_transaction_id] if PaperTrail.request.controller_info
  end

  # Define audit scope for this entity - includes category and its products if needed
  def self.audit_scope(category)
    # For now, just return the category's own audit transactions
    # Could be extended to include related ProductCategory records if needed
    AuditTransaction.where(item: category)
  end
end
