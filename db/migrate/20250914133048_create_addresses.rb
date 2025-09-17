class CreateAddresses < ActiveRecord::Migration[8.0]
  def change
    create_table :addresses do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :address_type_nm
      t.string :address_line1_txt
      t.string :address_line2_txt
      t.string :city_nm
      t.string :state_nm
      t.string :postal_code_nm
      t.string :country_code_nm
      t.boolean :is_default_flag

      t.timestamps
    end
  end
end
