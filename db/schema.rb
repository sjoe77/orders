# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_09_24_001546) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "addresses", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "address_type_nm"
    t.string "address_line1_txt"
    t.string "address_line2_txt"
    t.string "city_nm"
    t.string "state_nm"
    t.string "postal_code_nm"
    t.string "country_code_nm"
    t.boolean "is_default_flag"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_addresses_on_customer_id"
  end

  create_table "audit_transactions", force: :cascade do |t|
    t.text "reason", null: false
    t.datetime "created_at", precision: nil, null: false
    t.string "user_id"
    t.index ["created_at"], name: "index_audit_transactions_on_created_at"
    t.index ["user_id"], name: "index_audit_transactions_on_user_id"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name_nm", null: false
    t.text "description_txt"
    t.integer "parent_category_id"
    t.integer "display_order_num", default: 0
    t.boolean "active_flag", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["display_order_num"], name: "index_categories_on_display_order_num"
    t.index ["name_nm"], name: "index_categories_on_name_nm"
    t.index ["parent_category_id"], name: "index_categories_on_parent_category_id"
  end

  create_table "customers", force: :cascade do |t|
    t.string "customer_key_nm", null: false
    t.string "customer_num", null: false
    t.string "company_name_nm", null: false
    t.string "contact_first_name_nm"
    t.string "contact_last_name_nm"
    t.string "email_nm"
    t.string "phone_num"
    t.string "tax_id_num"
    t.decimal "credit_limit_amt", precision: 10, scale: 2, default: "0.0"
    t.boolean "active_flag", default: true, null: false
    t.integer "lock_version", default: 0, null: false
    t.integer "updated_by_user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_name_nm"], name: "index_customers_on_company_name_nm"
    t.index ["customer_key_nm"], name: "index_customers_on_customer_key_nm", unique: true
    t.index ["customer_num"], name: "index_customers_on_customer_num", unique: true
    t.index ["email_nm"], name: "index_customers_on_email_nm"
  end

  create_table "inventory_items", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.string "location_nm"
    t.integer "quantity_on_hand_cnt"
    t.integer "reserved_quantity_cnt"
    t.integer "reorder_point_cnt"
    t.integer "reorder_quantity_cnt"
    t.datetime "last_counted_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_inventory_items_on_product_id"
  end

  create_table "order_line_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "product_id", null: false
    t.integer "line_num", null: false
    t.integer "quantity_cnt", null: false
    t.decimal "unit_price_amt", precision: 10, scale: 2, null: false
    t.decimal "discount_amt", precision: 10, scale: 2, default: "0.0"
    t.decimal "line_total_amt", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id", "line_num"], name: "index_order_line_items_on_order_id_and_line_num", unique: true
    t.index ["order_id"], name: "index_order_line_items_on_order_id"
    t.index ["product_id"], name: "index_order_line_items_on_product_id"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "order_key_nm", null: false
    t.string "order_num", null: false
    t.datetime "order_date_at", precision: nil, null: false
    t.string "status_nm", default: "pending", null: false
    t.decimal "subtotal_amt", precision: 10, scale: 2, default: "0.0"
    t.decimal "tax_amt", precision: 10, scale: 2, default: "0.0"
    t.decimal "shipping_amt", precision: 10, scale: 2, default: "0.0"
    t.decimal "discount_amt", precision: 10, scale: 2, default: "0.0"
    t.decimal "total_amt", precision: 10, scale: 2, default: "0.0"
    t.integer "shipping_address_id"
    t.integer "billing_address_id"
    t.text "notes_txt"
    t.datetime "shipped_at", precision: nil
    t.datetime "delivered_at", precision: nil
    t.integer "lock_version", default: 0, null: false
    t.integer "updated_by_user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_orders_on_customer_id"
    t.index ["order_date_at"], name: "index_orders_on_order_date_at"
    t.index ["order_key_nm"], name: "index_orders_on_order_key_nm", unique: true
    t.index ["order_num"], name: "index_orders_on_order_num", unique: true
    t.index ["status_nm"], name: "index_orders_on_status_nm"
  end

  create_table "product_categories", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_product_categories_on_category_id"
    t.index ["product_id"], name: "index_product_categories_on_product_id"
  end

  create_table "product_tags", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_product_tags_on_product_id"
    t.index ["tag_id"], name: "index_product_tags_on_tag_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "product_key_nm", null: false
    t.string "sku_nm", null: false
    t.string "name_nm", null: false
    t.text "description_txt"
    t.decimal "unit_price_amt", precision: 10, scale: 2, null: false
    t.decimal "cost_amt", precision: 10, scale: 2
    t.decimal "weight_num", precision: 8, scale: 3
    t.text "dimensions_json"
    t.boolean "active_flag", default: true, null: false
    t.integer "lock_version", default: 0, null: false
    t.integer "updated_by_user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_flag"], name: "index_products_on_active_flag"
    t.index ["name_nm"], name: "index_products_on_name_nm"
    t.index ["product_key_nm"], name: "index_products_on_product_key_nm", unique: true
    t.index ["sku_nm"], name: "index_products_on_sku_nm", unique: true
  end

  create_table "tags", force: :cascade do |t|
    t.string "name_nm"
    t.string "color_code_nm"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "versions", force: :cascade do |t|
    t.string "whodunnit"
    t.datetime "created_at"
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.string "event", null: false
    t.text "object"
    t.bigint "audit_transaction_id"
    t.index ["audit_transaction_id"], name: "index_versions_on_audit_transaction_id"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "addresses", "customers"
  add_foreign_key "inventory_items", "products"
  add_foreign_key "order_line_items", "orders"
  add_foreign_key "order_line_items", "products"
  add_foreign_key "orders", "customers"
  add_foreign_key "product_categories", "categories"
  add_foreign_key "product_categories", "products"
  add_foreign_key "product_tags", "products"
  add_foreign_key "product_tags", "tags"
  add_foreign_key "versions", "audit_transactions"
end
