class OrderLineItem < ApplicationRecord
  belongs_to :order
  belongs_to :product

  validates :line_num, presence: true, uniqueness: { scope: :order_id }
  validates :quantity_cnt, presence: true, numericality: { greater_than: 0 }
  validates :unit_price_amt, presence: true, numericality: { greater_than: 0 }
  validates :discount_amt, numericality: { greater_than_or_equal_to: 0 }
  validates :line_total_amt, presence: true, numericality: { greater_than: 0 }

  before_validation :set_line_num, on: :create
  before_validation :set_unit_price, on: :create
  before_save :calculate_line_total

  scope :ordered, -> { order(:line_num) }

  private

  def set_line_num
    return if line_num.present?

    max_line = order.order_line_items.maximum(:line_num) || 0
    self.line_num = max_line + 1
  end

  def set_unit_price
    return if unit_price_amt.present?

    self.unit_price_amt = product.unit_price_amt
  end

  def calculate_line_total
    self.line_total_amt = (quantity_cnt * unit_price_amt) - discount_amt
  end
end
