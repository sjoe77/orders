class CreateCustomers < ActiveRecord::Migration[8.0]
  def change
    create_table :customers do |t|
      t.string :customer_key_nm, null: false
      t.string :customer_num, null: false
      t.string :company_name_nm, null: false
      t.string :contact_first_name_nm
      t.string :contact_last_name_nm
      t.string :email_nm
      t.string :phone_num
      t.string :tax_id_num
      t.decimal :credit_limit_amt, precision: 10, scale: 2, default: 0
      t.boolean :active_flag, default: true, null: false
      t.integer :lock_version, default: 0, null: false
      t.integer :updated_by_user_id

      t.timestamps
    end
    add_index :customers, :customer_key_nm, unique: true
    add_index :customers, :customer_num, unique: true
    add_index :customers, :company_name_nm
    add_index :customers, :email_nm
  end
end
