class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :orders do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :order_key_nm, null: false
      t.string :order_num, null: false
      t.timestamp :order_date_at, null: false
      t.string :status_nm, default: 'pending', null: false
      t.decimal :subtotal_amt, precision: 10, scale: 2, default: 0
      t.decimal :tax_amt, precision: 10, scale: 2, default: 0
      t.decimal :shipping_amt, precision: 10, scale: 2, default: 0
      t.decimal :discount_amt, precision: 10, scale: 2, default: 0
      t.decimal :total_amt, precision: 10, scale: 2, default: 0
      t.integer :shipping_address_id
      t.integer :billing_address_id
      t.text :notes_txt
      t.timestamp :shipped_at
      t.timestamp :delivered_at
      t.integer :lock_version, default: 0, null: false
      t.integer :updated_by_user_id

      t.timestamps
    end
    add_index :orders, :order_key_nm, unique: true
    add_index :orders, :order_num, unique: true
    add_index :orders, :status_nm
    add_index :orders, :order_date_at
  end
end
