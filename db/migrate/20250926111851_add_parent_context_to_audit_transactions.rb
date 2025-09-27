class AddParentContextToAuditTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :audit_transactions, :item_id, :integer
    add_column :audit_transactions, :item_type, :string

    # Add composite index for efficient queries by parent entity
    add_index :audit_transactions, [:item_type, :item_id], name: 'index_audit_transactions_on_parent_entity'
  end
end
