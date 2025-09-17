class Order < ApplicationRecord
  belongs_to :customer
  has_many :order_line_items, dependent: :destroy
  has_many :products, through: :order_line_items

  validates :order_key_nm, presence: true, uniqueness: true
  validates :order_num, presence: true, uniqueness: true
  validates :order_date_at, presence: true
  validates :status_nm, presence: true, inclusion: { in: %w[pending confirmed shipped delivered cancelled] }
  validates :subtotal_amt, :tax_amt, :shipping_amt, :discount_amt, :total_amt,
            numericality: { greater_than_or_equal_to: 0 }

  before_validation :generate_order_num, on: :create
  before_validation :set_order_date, on: :create
  before_save :calculate_totals

  scope :by_status, ->(status) { where(status_nm: status) }
  scope :recent, -> { order(order_date_at: :desc) }
  scope :by_customer, ->(customer_id) { where(customer_id: customer_id) }

  def shipping_address
    return nil unless shipping_address_id

    customer.addresses.find_by(id: shipping_address_id)
  end

  def billing_address
    return nil unless billing_address_id

    customer.addresses.find_by(id: billing_address_id)
  end

  def can_be_cancelled?
    %w[pending confirmed].include?(status_nm)
  end

  def can_be_shipped?
    status_nm == 'confirmed'
  end

  private

  def generate_order_num
    return if order_num.present?

    last_order = Order.order(:order_num).last
    next_num = last_order ? last_order.order_num.gsub(/\D/, '').to_i + 1 : 1
    self.order_num = "ORD-#{Date.current.year}-#{next_num.to_s.rjust(6, '0')}"
  end

  def set_order_date
    self.order_date_at ||= Time.current
  end

  def calculate_totals
    self.subtotal_amt = order_line_items.sum(&:line_total_amt)
    self.total_amt = subtotal_amt + tax_amt + shipping_amt - discount_amt
  end
end
