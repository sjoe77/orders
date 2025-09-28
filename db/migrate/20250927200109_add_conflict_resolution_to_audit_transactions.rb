class AddConflictResolutionToAuditTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :audit_transactions, :operation_status, :string, default: 'SUCCESS', null: false
    add_column :audit_transactions, :resolution_type, :string
    add_column :audit_transactions, :conflict_details, :jsonb

    # Add index for querying conflicts
    add_index :audit_transactions, :operation_status
    add_index :audit_transactions, :resolution_type
  end
end
