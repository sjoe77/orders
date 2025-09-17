class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.string :product_key_nm, null: false
      t.string :sku_nm, null: false
      t.string :name_nm, null: false
      t.text :description_txt
      t.decimal :unit_price_amt, precision: 10, scale: 2, null: false
      t.decimal :cost_amt, precision: 10, scale: 2
      t.decimal :weight_num, precision: 8, scale: 3
      t.text :dimensions_json
      t.boolean :active_flag, default: true, null: false
      t.integer :lock_version, default: 0, null: false
      t.integer :updated_by_user_id

      t.timestamps
    end
    add_index :products, :product_key_nm, unique: true
    add_index :products, :sku_nm, unique: true
    add_index :products, :name_nm
    add_index :products, :active_flag
  end
end
