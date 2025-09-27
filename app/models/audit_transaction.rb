class AuditTransaction < ApplicationRecord
  has_many :versions, class_name: 'PaperTrail::Version', foreign_key: 'audit_transaction_id', dependent: :nullify
  # belongs_to :user, optional: true # TODO: Uncomment when User model exists

  # Polymorphic association to the parent entity that triggered this audit transaction
  belongs_to :item, polymorphic: true, optional: true

  validates :reason, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_date, ->(date) { where(created_at: date.beginning_of_day..date.end_of_day) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :for_parent, ->(parent) { where(item: parent) }

  def version_count
    versions.count
  end

  def affected_models
    versions.group(:item_type).count
  end

  def user_display
    user_id || 'System'
  end

  # Helper method to find all versions for this transaction with proper user context
  def versions_with_user
    versions.includes(:audit_transaction)
  end

  # Get all audit transactions for a parent entity and its relationships
  def self.for_parent_with_relationships(parent)
    case parent.class.name
    when 'Customer'
      # Get audit transactions for customer and its addresses
      address_ids = parent.addresses.pluck(:id)

      # Transactions for the customer itself OR any of its addresses
      where(
        "(item_type = 'Customer' AND item_id = ?) OR (item_type = 'Address' AND item_id IN (?))",
        parent.id,
        address_ids.present? ? address_ids : [0]
      )
    else
      # For other entities, just return their own transactions
      for_parent(parent)
    end.recent.includes(:versions)
  end

  # Template method for enterprise applications - can be overridden per entity type
  def self.audit_scope_for_entity(entity)
    case entity.class.name
    when 'Customer'
      # Customer audit includes customer + addresses
      for_customer_graph(entity)
    when 'Order'
      # Order audit could include order + line items
      for_order_graph(entity)
    when 'Product'
      # Product audit could include product + categories + inventory
      for_product_graph(entity)
    else
      # Default: just the entity itself
      for_parent(entity)
    end
  end

  private

  def self.for_customer_graph(customer)
    address_ids = customer.addresses.pluck(:id)

    where(
      "(item_type = 'Customer' AND item_id = ?) OR (item_type = 'Address' AND item_id IN (?))",
      customer.id,
      address_ids.present? ? address_ids : [0]
    )
  end

  def self.for_order_graph(order)
    line_item_ids = order.line_items.pluck(:id) rescue []

    where(
      "(item_type = 'Order' AND item_id = ?) OR (item_type = 'OrderLineItem' AND item_id IN (?))",
      order.id,
      line_item_ids.present? ? line_item_ids : [0]
    )
  end

  def self.for_product_graph(product)
    # Example: Include product categories and inventory items
    category_link_ids = product.product_categories.pluck(:id) rescue []
    inventory_ids = product.inventory_items.pluck(:id) rescue []

    where(
      "(item_type = 'Product' AND item_id = ?) OR " \
      "(item_type = 'ProductCategory' AND item_id IN (?)) OR " \
      "(item_type = 'InventoryItem' AND item_id IN (?))",
      product.id,
      category_link_ids.present? ? category_link_ids : [0],
      inventory_ids.present? ? inventory_ids : [0]
    )
  end
end
