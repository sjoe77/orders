class RemoveUserIdFromAuditTransactions < ActiveRecord::Migration[8.0]
  def change
    remove_column :audit_transactions, :user_id, :string if column_exists?(:audit_transactions, :user_id)
  end
end
