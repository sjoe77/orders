class CreateInventoryItems < ActiveRecord::Migration[8.0]
  def change
    create_table :inventory_items do |t|
      t.references :product, null: false, foreign_key: true
      t.string :location_nm
      t.integer :quantity_on_hand_cnt
      t.integer :reserved_quantity_cnt
      t.integer :reorder_point_cnt
      t.integer :reorder_quantity_cnt
      t.timestamp :last_counted_at

      t.timestamps
    end
  end
end
