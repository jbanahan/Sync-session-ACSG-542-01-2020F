# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20101225221632) do

  create_table "addresses", :force => true do |t|
    t.string   "name"
    t.string   "line_1"
    t.string   "line_2"
    t.string   "line_3"
    t.string   "city"
    t.string   "state"
    t.string   "postal_code"
    t.integer  "company_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "country_id"
    t.boolean  "shipping"
  end

  create_table "companies", :force => true do |t|
    t.string   "name"
    t.boolean  "carrier"
    t.boolean  "vendor"
    t.boolean  "master"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "locked"
  end

  create_table "countries", :force => true do |t|
    t.string   "name"
    t.string   "iso_code",   :limit => 2
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "divisions", :force => true do |t|
    t.string   "name"
    t.integer  "company_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "histories", :force => true do |t|
    t.integer  "order_id"
    t.integer  "shipment_id"
    t.integer  "product_id"
    t.integer  "company_id"
    t.integer  "user_id"
    t.integer  "order_line_id"
    t.datetime "walked"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "history_type"
  end

  create_table "history_details", :force => true do |t|
    t.integer  "history_id"
    t.string   "key"
    t.string   "value"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "import_config_mappings", :force => true do |t|
    t.string   "model_field_uid"
    t.integer  "column"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "import_config_id"
  end

  create_table "import_configs", :force => true do |t|
    t.string   "name"
    t.string   "model_type"
    t.boolean  "ignore_first_row"
    t.string   "file_type"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "imported_files", :force => true do |t|
    t.string   "filename"
    t.integer  "size"
    t.string   "content_type"
    t.integer  "import_config_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "processed_at"
  end

  create_table "inventory_ins", :force => true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "inventory_outs", :force => true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "item_change_subscriptions", :force => true do |t|
    t.integer  "user_id"
    t.integer  "order_id"
    t.integer  "shipment_id"
    t.integer  "product_id"
    t.boolean  "app_message"
    t.boolean  "email"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "locations", :force => true do |t|
    t.string   "locode"
    t.string   "name"
    t.string   "sub_division"
    t.string   "function"
    t.string   "status"
    t.string   "iata"
    t.string   "coordinates"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "messages", :force => true do |t|
    t.string   "user_id"
    t.string   "subject"
    t.string   "body"
    t.string   "folder",     :default => "inbox"
    t.boolean  "read",       :default => false
    t.string   "link_name"
    t.string   "link_path"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "order_lines", :force => true do |t|
    t.integer  "product_id"
    t.decimal  "ordered_qty"
    t.decimal  "price_per_unit"
    t.date     "expected_ship_date"
    t.date     "expected_delivery_date"
    t.date     "ship_no_later_date"
    t.integer  "order_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "line_number"
  end

  create_table "orders", :force => true do |t|
    t.string   "order_number"
    t.date     "order_date"
    t.string   "buyer"
    t.string   "season"
    t.integer  "division_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "vendor_id"
    t.integer  "ship_to_id"
  end

  create_table "piece_sets", :force => true do |t|
    t.integer  "order_line_id"
    t.integer  "shipment_id"
    t.integer  "product_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.decimal  "quantity"
    t.integer  "inventory_in_id"
    t.string   "adjustment_type"
    t.integer  "inventory_out_id"
  end

  create_table "products", :force => true do |t|
    t.string   "unique_identifier"
    t.string   "part_number"
    t.string   "name"
    t.string   "description"
    t.integer  "vendor_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "division_id"
    t.string   "unit_of_measure"
  end

  create_table "shipments", :force => true do |t|
    t.date     "eta"
    t.date     "etd"
    t.date     "ata"
    t.date     "atd"
    t.integer  "ship_from_id"
    t.integer  "ship_to_id"
    t.integer  "carrier_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "reference"
    t.string   "bill_of_lading"
    t.string   "mode"
    t.integer  "vendor_id"
  end

  create_table "user_sessions", :force => true do |t|
    t.string   "username"
    t.string   "password"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", :force => true do |t|
    t.string   "username"
    t.string   "email"
    t.string   "crypted_password"
    t.string   "password_salt"
    t.string   "persistence_token"
    t.integer  "failed_login_count", :default => 0, :null => false
    t.datetime "last_request_at"
    t.datetime "current_login_at"
    t.datetime "last_login_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "disabled"
    t.integer  "company_id"
    t.string   "first_name"
    t.string   "last_name"
    t.string   "time_zone"
    t.string   "email_format"
  end

end
