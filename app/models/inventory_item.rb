class InventoryItem < ApplicationRecord
  belongs_to :product

  validates :location_nm, presence: true
  validates :quantity_on_hand_cnt, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :reserved_quantity_cnt, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :reorder_point_cnt, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validates :reorder_quantity_cnt, numericality: { greater_than: 0 }, allow_blank: true
  validates :product_id, uniqueness: { scope: :location_nm }

  scope :by_location, ->(location) { where(location_nm: location) }
  scope :low_stock, -> { where('quantity_on_hand_cnt <= reorder_point_cnt') }

  def available_quantity
    quantity_on_hand_cnt - reserved_quantity_cnt
  end

  def needs_reorder?
    return false unless reorder_point_cnt

    quantity_on_hand_cnt <= reorder_point_cnt
  end
end
