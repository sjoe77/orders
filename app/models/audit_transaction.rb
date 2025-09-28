class AuditTransaction < ApplicationRecord
  has_many :versions, class_name: 'PaperTrail::Version', foreign_key: 'audit_transaction_id', dependent: :nullify
  # belongs_to :user, optional: true # TODO: Uncomment when User model exists

  # Polymorphic association to the parent entity that triggered this audit transaction
  belongs_to :item, polymorphic: true, optional: true

  validates :reason, presence: true
  validates :operation_status, presence: true, inclusion: {
    in: %w[SUCCESS CONFLICT_RESOLVED CONFLICT_FAILED],
    message: "%{value} is not a valid operation status"
  }

  scope :recent, -> { order(created_at: :desc) }
  scope :by_date, ->(date) { where(created_at: date.beginning_of_day..date.end_of_day) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :for_parent, ->(parent) { where(item: parent) }
  scope :successful, -> { where(operation_status: 'SUCCESS') }
  scope :conflicts, -> { where(operation_status: ['CONFLICT_RESOLVED', 'CONFLICT_FAILED']) }
  scope :by_resolution_type, ->(type) { where(resolution_type: type) }

  def version_count
    versions.count
  end

  def affected_models
    versions.group(:item_type).count
  end

  def user_display
    user_id || 'System'
  end

  def successful?
    operation_status == 'SUCCESS'
  end

  def conflict?
    operation_status.in?(['CONFLICT_RESOLVED', 'CONFLICT_FAILED'])
  end

  def auto_resolved?
    resolution_type&.start_with?('AUTO_RESOLVED')
  end

  def manual_resolution?
    resolution_type == 'MANUAL_RESOLUTION'
  end

  # Helper method to find all versions for this transaction with proper user context
  def versions_with_user
    versions.includes(:audit_transaction)
  end

  # Generic audit scope method - delegates to entity models
  def self.audit_scope_for_entity(entity)
    # Check if the entity defines its own audit scope
    if entity.class.respond_to?(:audit_scope)
      entity.class.audit_scope(entity)
    else
      # Default: just the entity itself
      for_parent(entity)
    end
  end
end
