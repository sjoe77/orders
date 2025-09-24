class UpdateVersionsWithTransactionId < ActiveRecord::Migration[8.0]
  def change
    # Add reference already created the index, so skip it
    unless index_exists?(:versions, :audit_transaction_id)
      add_reference :versions, :audit_transaction, foreign_key: true, null: true
    end

    # Remove the old duplicated columns
    remove_column :versions, :reason, :text if column_exists?(:versions, :reason)
    remove_column :versions, :transaction_key, :string if column_exists?(:versions, :transaction_key)
  end
end
