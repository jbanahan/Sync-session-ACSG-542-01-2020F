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

ActiveRecord::Schema.define(:version => 20110707151450) do

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

  add_index "addresses", ["company_id"], :name => "index_addresses_on_company_id"

  create_table "attachment_types", :force => true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "attachments", :force => true do |t|
    t.integer  "attachable_id"
    t.string   "attachable_type"
    t.string   "attached_file_name"
    t.string   "attached_content_type"
    t.integer  "attached_file_size"
    t.datetime "attached_updated_at"
    t.integer  "uploaded_by_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "attachment_type"
  end

  add_index "attachments", ["attachable_id", "attachable_type"], :name => "index_attachments_on_attachable_id_and_attachable_type"

  create_table "change_record_messages", :force => true do |t|
    t.integer  "change_record_id"
    t.string   "message"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "change_records", :force => true do |t|
    t.integer  "file_import_result_id"
    t.integer  "recordable_id"
    t.string   "recordable_type"
    t.integer  "record_sequence_number"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "failed"
  end

  add_index "change_records", ["file_import_result_id"], :name => "index_change_records_on_file_import_result_id"

  create_table "classifications", :force => true do |t|
    t.integer  "country_id"
    t.string   "binding_ruling_number"
    t.integer  "product_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "classifications", ["country_id"], :name => "index_classifications_on_country_id"
  add_index "classifications", ["product_id"], :name => "index_classifications_on_product_id"

  create_table "comments", :force => true do |t|
    t.text     "body"
    t.string   "subject"
    t.integer  "user_id"
    t.integer  "commentable_id"
    t.string   "commentable_type"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "comments", ["commentable_id", "commentable_type"], :name => "index_comments_on_commentable_id_and_commentable_type"

  create_table "companies", :force => true do |t|
    t.string   "name"
    t.boolean  "carrier"
    t.boolean  "vendor"
    t.boolean  "master"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "locked"
    t.boolean  "customer"
    t.string   "system_code"
  end

  add_index "companies", ["carrier"], :name => "index_companies_on_carrier"
  add_index "companies", ["customer"], :name => "index_companies_on_customer"
  add_index "companies", ["master"], :name => "index_companies_on_master"
  add_index "companies", ["vendor"], :name => "index_companies_on_vendor"

  create_table "countries", :force => true do |t|
    t.string   "name"
    t.string   "iso_code",            :limit => 2
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "import_location"
    t.integer  "classification_rank"
  end

  create_table "custom_definitions", :force => true do |t|
    t.string   "label"
    t.string   "data_type"
    t.integer  "rank"
    t.string   "module_type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "tool_tip"
    t.string   "default_value"
  end

  add_index "custom_definitions", ["module_type"], :name => "index_custom_definitions_on_module_type"

  create_table "custom_values", :force => true do |t|
    t.integer  "customizable_id"
    t.string   "customizable_type"
    t.string   "string_value"
    t.decimal  "decimal_value",        :precision => 13, :scale => 4
    t.integer  "integer_value"
    t.date     "date_value"
    t.integer  "custom_definition_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "text_value"
    t.boolean  "boolean_value"
  end

  add_index "custom_values", ["custom_definition_id"], :name => "index_custom_values_on_custom_definition_id"
  add_index "custom_values", ["customizable_id", "customizable_type", "custom_definition_id"], :name => "cv_unique_composite"
  add_index "custom_values", ["customizable_id", "customizable_type"], :name => "index_custom_values_on_customizable_id_and_customizable_type"

  create_table "dashboard_widgets", :force => true do |t|
    t.integer  "user_id"
    t.integer  "search_setup_id"
    t.integer  "rank"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "dashboard_widgets", ["user_id"], :name => "index_dashboard_widgets_on_user_id"

  create_table "debug_records", :force => true do |t|
    t.integer  "user_id"
    t.string   "request_method"
    t.text     "request_params"
    t.string   "request_path"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "delayed_jobs", :force => true do |t|
    t.integer  "priority",   :default => 0
    t.integer  "attempts",   :default => 0
    t.text     "handler"
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "delayed_jobs", ["priority", "run_at"], :name => "delayed_jobs_priority"

  create_table "deliveries", :force => true do |t|
    t.integer  "ship_from_id"
    t.integer  "ship_to_id"
    t.integer  "carrier_id"
    t.string   "reference"
    t.string   "mode"
    t.integer  "customer_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "delivery_lines", :force => true do |t|
    t.integer  "line_number"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "delivery_id"
    t.integer  "product_id"
    t.decimal  "quantity",    :precision => 13, :scale => 4
  end

  add_index "delivery_lines", ["delivery_id"], :name => "index_delivery_lines_on_delivery_id"

  create_table "divisions", :force => true do |t|
    t.string   "name"
    t.integer  "company_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "entity_snapshots", :force => true do |t|
    t.string   "recordable_type"
    t.integer  "recordable_id"
    t.text     "snapshot"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "entity_snapshots", ["recordable_id", "recordable_type"], :name => "index_entity_snapshots_on_recordable_id_and_recordable_type"
  add_index "entity_snapshots", ["user_id"], :name => "index_entity_snapshots_on_user_id"

  create_table "entity_type_fields", :force => true do |t|
    t.string   "model_field_uid"
    t.integer  "entity_type_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "entity_type_fields", ["entity_type_id"], :name => "index_entity_type_fields_on_entity_type_id"

  create_table "entity_types", :force => true do |t|
    t.string   "name"
    t.string   "module_type"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "field_labels", :force => true do |t|
    t.string   "model_field_uid"
    t.string   "label"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "field_labels", ["model_field_uid"], :name => "index_field_labels_on_model_field_uid"

  create_table "field_validator_rules", :force => true do |t|
    t.string   "model_field_uid"
    t.string   "module_type"
    t.decimal  "greater_than",           :precision => 13, :scale => 4
    t.decimal  "less_than",              :precision => 13, :scale => 4
    t.integer  "more_than_ago"
    t.integer  "less_than_from_now"
    t.string   "more_than_ago_uom"
    t.string   "less_than_from_now_uom"
    t.date     "greater_than_date"
    t.date     "less_than_date"
    t.string   "regex"
    t.text     "comment"
    t.string   "custom_message"
    t.boolean  "required"
    t.string   "starts_with"
    t.string   "ends_with"
    t.string   "contains"
    t.text     "one_of"
    t.integer  "minimum_length"
    t.integer  "maximum_length"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "custom_definition_id"
  end

  create_table "file_import_results", :force => true do |t|
    t.integer  "imported_file_id"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.integer  "run_by_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "file_import_results", ["imported_file_id", "finished_at"], :name => "index_file_import_results_on_imported_file_id_and_finished_at"

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
    t.integer  "sales_order_id"
    t.integer  "sales_order_line_id"
    t.integer  "delivery_id"
  end

  create_table "history_details", :force => true do |t|
    t.integer  "history_id"
    t.string   "source_key"
    t.string   "value"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "imported_files", :force => true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "processed_at"
    t.integer  "search_setup_id"
    t.boolean  "ignore_first_row"
    t.string   "attached_file_name"
    t.string   "attached_content_type"
    t.integer  "attached_file_size"
    t.datetime "attached_updated_at"
    t.integer  "user_id"
    t.string   "module_type"
  end

  add_index "imported_files", ["user_id"], :name => "index_imported_files_on_user_id"

  create_table "item_change_subscriptions", :force => true do |t|
    t.integer  "user_id"
    t.integer  "order_id"
    t.integer  "shipment_id"
    t.integer  "product_id"
    t.boolean  "app_message"
    t.boolean  "email"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "sales_order_id"
    t.integer  "delivery_id"
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

  create_table "master_setups", :force => true do |t|
    t.string   "uuid"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "logo_image"
    t.string   "system_code"
    t.boolean  "order_enabled",          :default => true, :null => false
    t.boolean  "shipment_enabled",       :default => true, :null => false
    t.boolean  "sales_order_enabled",    :default => true, :null => false
    t.boolean  "delivery_enabled",       :default => true, :null => false
    t.boolean  "classification_enabled", :default => true, :null => false
    t.boolean  "ftp_polling_active"
    t.text     "system_message"
  end

  create_table "messages", :force => true do |t|
    t.string   "user_id"
    t.string   "subject"
    t.string   "body"
    t.string   "folder",     :default => "inbox"
    t.boolean  "viewed",     :default => false
    t.string   "link_name"
    t.string   "link_path"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "messages", ["user_id"], :name => "index_messages_on_user_id"

  create_table "milestone_definitions", :force => true do |t|
    t.integer "milestone_plan_id"
    t.string  "model_field_uid"
    t.integer "days_after_previous"
    t.integer "previous_milestone_definition_id"
    t.boolean "final_milestone"
    t.integer "custom_definition_id"
  end

  add_index "milestone_definitions", ["milestone_plan_id"], :name => "index_milestone_definitions_on_milestone_plan_id"

  create_table "milestone_forecast_sets", :force => true do |t|
    t.integer  "piece_set_id"
    t.string   "state"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "milestone_forecast_sets", ["piece_set_id"], :name => "one_per_piece_set"
  add_index "milestone_forecast_sets", ["state"], :name => "mfs_state"

  create_table "milestone_forecasts", :force => true do |t|
    t.integer  "milestone_definition_id"
    t.integer  "milestone_forecast_set_id"
    t.date     "planned"
    t.date     "forecast"
    t.string   "state"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "milestone_forecasts", ["milestone_forecast_set_id", "milestone_definition_id"], :name => "unique_forecasts"
  add_index "milestone_forecasts", ["state"], :name => "mf_state"

  create_table "milestone_plans", :force => true do |t|
    t.string   "name"
    t.string   "code"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "official_quotas", :force => true do |t|
    t.string   "hts_code"
    t.integer  "country_id"
    t.decimal  "square_meter_equivalent_factor", :precision => 13, :scale => 4
    t.string   "category"
    t.string   "unit_of_measure"
    t.integer  "official_tariff_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "official_quotas", ["country_id", "hts_code"], :name => "index_official_quotas_on_country_id_and_hts_code"

  create_table "official_tariff_meta_datas", :force => true do |t|
    t.string   "hts_code"
    t.integer  "country_id"
    t.boolean  "auto_classify_ignore"
    t.text     "notes"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "official_tariff_meta_datas", ["country_id", "hts_code"], :name => "index_official_tariff_meta_datas_on_country_id_and_hts_code"

  create_table "official_tariffs", :force => true do |t|
    t.integer  "country_id"
    t.string   "hts_code"
    t.text     "full_description"
    t.string   "special_rates"
    t.string   "general_rate"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "chapter",                          :limit => 800
    t.string   "heading",                          :limit => 800
    t.string   "sub_heading",                      :limit => 800
    t.string   "remaining_description",            :limit => 800
    t.string   "add_valorem_rate"
    t.string   "per_unit_rate"
    t.string   "calculation_method"
    t.string   "most_favored_nation_rate"
    t.string   "general_preferential_tariff_rate"
    t.string   "erga_omnes_rate"
    t.string   "unit_of_measure"
    t.string   "column_2_rate"
    t.string   "import_regulations"
    t.string   "export_regulations"
  end

  add_index "official_tariffs", ["country_id", "hts_code"], :name => "index_official_tariffs_on_country_id_and_hts_code"
  add_index "official_tariffs", ["hts_code"], :name => "index_official_tariffs_on_hts_code"

  create_table "order_lines", :force => true do |t|
    t.decimal  "price_per_unit", :precision => 13, :scale => 4
    t.integer  "order_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "line_number"
    t.integer  "product_id"
    t.decimal  "quantity",       :precision => 13, :scale => 4
  end

  add_index "order_lines", ["order_id"], :name => "index_order_lines_on_order_id"

  create_table "orders", :force => true do |t|
    t.string   "order_number"
    t.date     "order_date"
    t.integer  "division_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "vendor_id"
    t.integer  "ship_to_id"
  end

  create_table "piece_sets", :force => true do |t|
    t.integer  "order_line_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.decimal  "quantity",            :precision => 13, :scale => 4
    t.string   "adjustment_type"
    t.integer  "sales_order_line_id"
    t.boolean  "unshipped_remainder"
    t.integer  "shipment_line_id"
    t.integer  "delivery_line_id"
    t.integer  "milestone_plan_id"
  end

  create_table "products", :force => true do |t|
    t.string   "unique_identifier"
    t.string   "name"
    t.integer  "vendor_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "division_id"
    t.string   "unit_of_measure"
    t.integer  "status_rule_id"
    t.datetime "changed_at"
    t.integer  "entity_type_id"
  end

  add_index "products", ["name"], :name => "index_products_on_name"
  add_index "products", ["unique_identifier"], :name => "index_products_on_unique_identifier"

  create_table "public_fields", :force => true do |t|
    t.string   "model_field_uid"
    t.boolean  "searchable"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "public_fields", ["model_field_uid"], :name => "index_public_fields_on_model_field_uid"

  create_table "sales_order_lines", :force => true do |t|
    t.decimal  "price_per_unit", :precision => 13, :scale => 4
    t.integer  "sales_order_id"
    t.integer  "line_number"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "product_id"
    t.decimal  "quantity",       :precision => 13, :scale => 4
  end

  add_index "sales_order_lines", ["sales_order_id"], :name => "index_sales_order_lines_on_sales_order_id"

  create_table "sales_orders", :force => true do |t|
    t.string   "order_number"
    t.date     "order_date"
    t.integer  "customer_id"
    t.integer  "division_id"
    t.integer  "ship_to_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "search_columns", :force => true do |t|
    t.integer  "search_setup_id"
    t.integer  "rank"
    t.string   "model_field_uid"
    t.integer  "custom_definition_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "imported_file_id"
  end

  add_index "search_columns", ["search_setup_id"], :name => "index_search_columns_on_search_setup_id"

  create_table "search_criterions", :force => true do |t|
    t.string   "operator"
    t.string   "value"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "status_rule_id"
    t.string   "model_field_uid"
    t.integer  "search_setup_id"
    t.integer  "custom_definition_id"
  end

  add_index "search_criterions", ["search_setup_id"], :name => "index_search_criterions_on_search_setup_id"

  create_table "search_runs", :force => true do |t|
    t.text     "result_cache"
    t.integer  "position"
    t.integer  "search_setup_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "starting_cache_position"
    t.datetime "last_accessed"
    t.integer  "imported_file_id"
    t.integer  "user_id"
  end

  add_index "search_runs", ["user_id", "last_accessed"], :name => "index_search_runs_on_user_id_and_last_accessed"

  create_table "search_schedules", :force => true do |t|
    t.string   "email_addresses"
    t.string   "ftp_server"
    t.string   "ftp_username"
    t.string   "ftp_password"
    t.string   "ftp_subfolder"
    t.string   "sftp_server"
    t.string   "sftp_username"
    t.string   "sftp_password"
    t.string   "sftp_subfolder"
    t.boolean  "run_monday"
    t.boolean  "run_tuesday"
    t.boolean  "run_wednesday"
    t.boolean  "run_thursday"
    t.boolean  "run_friday"
    t.boolean  "run_saturday"
    t.boolean  "run_sunday"
    t.integer  "run_hour"
    t.datetime "last_start_time"
    t.datetime "last_finish_time"
    t.integer  "search_setup_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "download_format"
  end

  add_index "search_schedules", ["search_setup_id"], :name => "index_search_schedules_on_search_setup_id"

  create_table "search_setups", :force => true do |t|
    t.string   "name"
    t.integer  "user_id"
    t.string   "module_type"
    t.boolean  "simple"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "download_format"
  end

  add_index "search_setups", ["user_id", "module_type"], :name => "index_search_setups_on_user_id_and_module_type"

  create_table "shipment_lines", :force => true do |t|
    t.integer  "line_number"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "shipment_id"
    t.integer  "product_id"
    t.decimal  "quantity",    :precision => 13, :scale => 4
  end

  add_index "shipment_lines", ["shipment_id"], :name => "index_shipment_lines_on_shipment_id"

  create_table "shipments", :force => true do |t|
    t.integer  "ship_from_id"
    t.integer  "ship_to_id"
    t.integer  "carrier_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "reference"
    t.string   "mode"
    t.integer  "vendor_id"
  end

  create_table "sort_criterions", :force => true do |t|
    t.integer  "search_setup_id"
    t.integer  "rank"
    t.string   "model_field_uid"
    t.integer  "custom_definition_id"
    t.boolean  "descending"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "sort_criterions", ["search_setup_id"], :name => "index_sort_criterions_on_search_setup_id"

  create_table "status_rules", :force => true do |t|
    t.string   "module_type"
    t.string   "name"
    t.string   "description"
    t.integer  "test_rank"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "tariff_records", :force => true do |t|
    t.string   "hts_1"
    t.string   "hts_2"
    t.string   "hts_3"
    t.integer  "classification_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "line_number"
  end

  add_index "tariff_records", ["classification_id"], :name => "index_tariff_records_on_classification_id"

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
    t.integer  "failed_login_count",     :default => 0,  :null => false
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
    t.boolean  "admin"
    t.boolean  "sys_admin"
    t.string   "perishable_token",       :default => "", :null => false
    t.datetime "debug_expires"
    t.datetime "tos_accept"
    t.boolean  "search_open"
    t.boolean  "classification_comment"
    t.boolean  "classification_attach"
    t.boolean  "order_view"
    t.boolean  "order_edit"
    t.boolean  "order_delete"
    t.boolean  "order_comment"
    t.boolean  "order_attach"
    t.boolean  "shipment_view"
    t.boolean  "shipment_edit"
    t.boolean  "shipment_delete"
    t.boolean  "shipment_comment"
    t.boolean  "shipment_attach"
    t.boolean  "sales_order_view"
    t.boolean  "sales_order_edit"
    t.boolean  "sales_order_delete"
    t.boolean  "sales_order_comment"
    t.boolean  "sales_order_attach"
    t.boolean  "delivery_view"
    t.boolean  "delivery_edit"
    t.boolean  "delivery_delete"
    t.boolean  "delivery_comment"
    t.boolean  "delivery_attach"
    t.boolean  "product_view"
    t.boolean  "product_edit"
    t.boolean  "product_delete"
    t.boolean  "product_comment"
    t.boolean  "product_attach"
    t.boolean  "classification_edit"
  end

  create_table "worksheet_config_mappings", :force => true do |t|
    t.integer  "row"
    t.integer  "column"
    t.string   "model_field_uid"
    t.integer  "custom_definition_id"
    t.integer  "worksheet_config_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "worksheet_configs", :force => true do |t|
    t.string   "name"
    t.string   "module_type"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
