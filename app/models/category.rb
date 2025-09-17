class Category < ApplicationRecord
  has_many :product_categories, dependent: :destroy
  has_many :products, through: :product_categories
  belongs_to :parent_category, class_name: 'Category', optional: true
  has_many :subcategories, class_name: 'Category', foreign_key: 'parent_category_id'

  validates :name_nm, presence: true, uniqueness: true
  validates :display_order_num, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(active_flag: true) }
  scope :root_categories, -> { where(parent_category_id: nil) }
  scope :ordered, -> { order(:display_order_num, :name_nm) }

  def hierarchical_name
    return name_nm unless parent_category

    "#{parent_category.hierarchical_name} > #{name_nm}"
  end
end
