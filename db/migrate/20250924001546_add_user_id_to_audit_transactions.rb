class AddUserIdToAuditTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :audit_transactions, :user_id, :string
    add_index :audit_transactions, :user_id
  end
end
