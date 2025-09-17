class CreateOrderLineItems < ActiveRecord::Migration[8.0]
  def change
    create_table :order_line_items do |t|
      t.references :order, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :line_num, null: false
      t.integer :quantity_cnt, null: false
      t.decimal :unit_price_amt, precision: 10, scale: 2, null: false
      t.decimal :discount_amt, precision: 10, scale: 2, default: 0
      t.decimal :line_total_amt, precision: 10, scale: 2, null: false

      t.timestamps
    end
    add_index :order_line_items, [:order_id, :line_num], unique: true
  end
end
