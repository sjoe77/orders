class AddTransactionKeyToVersions < ActiveRecord::Migration[8.0]
  def change
    add_column :versions, :transaction_key, :string
    add_index :versions, :transaction_key
  end
end
