class CreateAuditTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_transactions do |t|
      t.text :reason, null: false
      t.string :user_id  # Track who made the change
      t.timestamp :created_at, null: false
    end

    add_index :audit_transactions, :created_at
  end
end
