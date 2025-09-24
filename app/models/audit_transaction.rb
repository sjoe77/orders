class AuditTransaction < ApplicationRecord
  has_many :versions, class_name: 'PaperTrail::Version', foreign_key: 'audit_transaction_id', dependent: :nullify
  # belongs_to :user, optional: true # TODO: Uncomment when User model exists

  validates :reason, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_date, ->(date) { where(created_at: date.beginning_of_day..date.end_of_day) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }

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
end
