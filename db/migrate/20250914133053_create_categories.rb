class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories do |t|
      t.string :name_nm, null: false
      t.text :description_txt
      t.integer :parent_category_id
      t.integer :display_order_num, default: 0
      t.boolean :active_flag, default: true, null: false

      t.timestamps
    end
    add_index :categories, :name_nm
    add_index :categories, :parent_category_id
    add_index :categories, :display_order_num
  end
end
