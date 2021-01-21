# encoding: UTF-8
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
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20201021164353) do

  create_table "addresses", force: :cascade do |t|
    t.string   "name",            limit: 255
    t.string   "line_1",          limit: 255
    t.string   "line_2",          limit: 255
    t.string   "line_3",          limit: 255
    t.string   "city",            limit: 255
    t.string   "state",           limit: 255
    t.string   "postal_code",     limit: 255
    t.integer  "company_id",      limit: 4
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
    t.integer  "country_id",      limit: 4
    t.boolean  "shipping"
    t.string   "address_hash",    limit: 255
    t.string   "system_code",     limit: 255
    t.boolean  "in_address_book"
    t.string   "phone_number",    limit: 255
    t.string   "fax_number",      limit: 255
    t.string   "address_type",    limit: 255
    t.integer  "port_id",         limit: 4
  end

  add_index "addresses", ["address_hash"], name: "index_addresses_on_address_hash", using: :btree
  add_index "addresses", ["company_id"], name: "index_addresses_on_company_id", using: :btree
  add_index "addresses", ["port_id"], name: "index_addresses_on_port_id", using: :btree
  add_index "addresses", ["system_code"], name: "index_addresses_on_system_code", using: :btree

  create_table "announcements", force: :cascade do |t|
    t.string   "title",      limit: 255
    t.string   "category",   limit: 255
    t.text     "text",       limit: 16777215
    t.text     "comments",   limit: 65535
    t.datetime "start_at"
    t.datetime "end_at"
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
  end

  create_table "answer_comments", force: :cascade do |t|
    t.integer  "answer_id",  limit: 4
    t.integer  "user_id",    limit: 4
    t.text     "content",    limit: 65535
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
    t.boolean  "private"
  end

  add_index "answer_comments", ["answer_id"], name: "index_answer_comments_on_answer_id", using: :btree

  create_table "answers", force: :cascade do |t|
    t.integer  "survey_response_id", limit: 4
    t.integer  "question_id",        limit: 4
    t.string   "choice",             limit: 255
    t.string   "rating",             limit: 255
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
  end

  add_index "answers", ["question_id"], name: "index_answers_on_question_id", using: :btree
  add_index "answers", ["survey_response_id"], name: "index_answers_on_survey_response_id", using: :btree

  create_table "api_sessions", force: :cascade do |t|
    t.string   "endpoint",             limit: 255
    t.string   "class_name",           limit: 255
    t.string   "last_server_response", limit: 255
    t.string   "request_file_name",    limit: 255
    t.integer  "retry_count",          limit: 4
    t.datetime "created_at",                       null: false
    t.datetime "updated_at",                       null: false
  end

  create_table "archived_files", force: :cascade do |t|
    t.string   "file_type",  limit: 255
    t.string   "comment",    limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "archived_files", ["created_at"], name: "index_archived_files_on_created_at", using: :btree
  add_index "archived_files", ["file_type"], name: "index_archived_files_on_file_type", using: :btree

  create_table "attachment_archive_manifests", force: :cascade do |t|
    t.datetime "start_at"
    t.datetime "finish_at"
    t.integer  "company_id", limit: 4
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
  end

  add_index "attachment_archive_manifests", ["company_id"], name: "index_attachment_archive_manifests_on_company_id", using: :btree

  create_table "attachment_archive_setups", force: :cascade do |t|
    t.integer  "company_id",                      limit: 4
    t.date     "start_date"
    t.datetime "created_at",                                    null: false
    t.datetime "updated_at",                                    null: false
    t.boolean  "combine_attachments"
    t.text     "combined_attachment_order",       limit: 65535
    t.string   "archive_scheme",                  limit: 255
    t.date     "end_date"
    t.boolean  "include_only_listed_attachments"
    t.boolean  "send_in_real_time"
    t.string   "send_as_customer_number",         limit: 255
    t.text     "output_path",                     limit: 65535
  end

  add_index "attachment_archive_setups", ["company_id"], name: "index_attachment_archive_setups_on_company_id", using: :btree

  create_table "attachment_archives", force: :cascade do |t|
    t.integer  "company_id", limit: 4
    t.string   "name",       limit: 255
    t.datetime "start_at"
    t.datetime "finish_at"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "attachment_archives", ["company_id"], name: "index_attachment_archives_on_company_id", using: :btree

  create_table "attachment_archives_attachments", force: :cascade do |t|
    t.integer "attachment_archive_id", limit: 4
    t.integer "attachment_id",         limit: 4
    t.string  "file_name",             limit: 255
  end

  add_index "attachment_archives_attachments", ["attachment_archive_id"], name: "arch_id", using: :btree
  add_index "attachment_archives_attachments", ["attachment_id"], name: "att_id", using: :btree

  create_table "attachment_process_jobs", force: :cascade do |t|
    t.integer  "attachment_id",           limit: 4
    t.string   "job_name",                limit: 255
    t.datetime "start_at"
    t.datetime "finish_at"
    t.string   "error_message",           limit: 255
    t.integer  "user_id",                 limit: 4
    t.integer  "attachable_id",           limit: 4
    t.string   "attachable_type",         limit: 255
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
    t.integer  "manufacturer_address_id", limit: 4
  end

  add_index "attachment_process_jobs", ["attachable_id", "attachable_type"], name: "attachable_idx", using: :btree
  add_index "attachment_process_jobs", ["attachment_id"], name: "index_attachment_process_jobs_on_attachment_id", using: :btree
  add_index "attachment_process_jobs", ["user_id"], name: "index_attachment_process_jobs_on_user_id", using: :btree

  create_table "attachment_types", force: :cascade do |t|
    t.string   "name",                         limit: 255
    t.datetime "created_at",                               null: false
    t.datetime "updated_at",                               null: false
    t.string   "kewill_document_code",         limit: 255
    t.string   "kewill_attachment_type",       limit: 255
    t.boolean  "disable_multiple_kewill_docs"
  end

  create_table "attachments", force: :cascade do |t|
    t.integer  "attachable_id",           limit: 4
    t.string   "attachable_type",         limit: 255
    t.string   "attached_file_name",      limit: 255
    t.string   "attached_content_type",   limit: 255
    t.integer  "attached_file_size",      limit: 4
    t.datetime "attached_updated_at"
    t.integer  "uploaded_by_id",          limit: 4
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
    t.string   "attachment_type",         limit: 255
    t.datetime "source_system_timestamp"
    t.string   "alliance_suffix",         limit: 255
    t.integer  "alliance_revision",       limit: 4
    t.string   "checksum",                limit: 255
    t.boolean  "is_private"
  end

  add_index "attachments", ["attachable_id", "attachable_type"], name: "index_attachments_on_attachable_id_and_attachable_type", using: :btree
  add_index "attachments", ["updated_at"], name: "index_attachments_on_updated_at", using: :btree

  create_table "automated_billing_setups", force: :cascade do |t|
    t.string   "customer_number", limit: 255
    t.boolean  "enabled"
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
  end

  add_index "automated_billing_setups", ["customer_number"], name: "index_automated_billing_setups_on_customer_number", using: :btree

  create_table "aws_backup_sessions", force: :cascade do |t|
    t.string   "name",       limit: 255
    t.datetime "start_time"
    t.datetime "end_time"
    t.text     "log",        limit: 65535
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
  end

  create_table "aws_snapshots", force: :cascade do |t|
    t.string   "snapshot_id",           limit: 255
    t.string   "description",           limit: 255
    t.string   "instance_id",           limit: 255
    t.string   "volume_id",             limit: 255
    t.text     "tags_json",             limit: 65535
    t.datetime "start_time"
    t.datetime "end_time"
    t.boolean  "errored"
    t.datetime "purged_at"
    t.integer  "aws_backup_session_id", limit: 4,     null: false
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
  end

  add_index "aws_snapshots", ["aws_backup_session_id"], name: "index_aws_snapshots_on_aws_backup_session_id", using: :btree
  add_index "aws_snapshots", ["instance_id"], name: "index_aws_snapshots_on_instance_id", using: :btree
  add_index "aws_snapshots", ["snapshot_id"], name: "index_aws_snapshots_on_snapshot_id", using: :btree

  create_table "bill_of_lading_containers", force: :cascade do |t|
    t.integer  "bill_of_lading_id", limit: 4
    t.integer  "container_id",      limit: 4
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
  end

  create_table "bill_of_ladings", force: :cascade do |t|
    t.integer  "entry_id",          limit: 4
    t.string   "bill_type",         limit: 255
    t.string   "bill_number",       limit: 255
    t.integer  "bill_of_lading_id", limit: 4
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
  end

  create_table "bill_of_materials_links", force: :cascade do |t|
    t.integer "parent_product_id", limit: 4
    t.integer "child_product_id",  limit: 4
    t.integer "quantity",          limit: 4
  end

  add_index "bill_of_materials_links", ["child_product_id"], name: "index_bill_of_materials_links_on_child_product_id", using: :btree
  add_index "bill_of_materials_links", ["parent_product_id"], name: "index_bill_of_materials_links_on_parent_product_id", using: :btree

  create_table "billable_events", force: :cascade do |t|
    t.integer  "billable_eventable_id",   limit: 4,   null: false
    t.string   "billable_eventable_type", limit: 255, null: false
    t.integer  "entity_snapshot_id",      limit: 4,   null: false
    t.string   "event_type",              limit: 255
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
  end

  add_index "billable_events", ["billable_eventable_type", "billable_eventable_id"], name: "index_billable_events_on_billable_eventable", using: :btree
  add_index "billable_events", ["entity_snapshot_id"], name: "index_billable_events_on_entity_snapshot_id", using: :btree

  create_table "booking_lines", force: :cascade do |t|
    t.integer  "product_id",     limit: 4
    t.integer  "shipment_id",    limit: 4
    t.integer  "line_number",    limit: 4
    t.decimal  "quantity",                   precision: 13, scale: 4
    t.datetime "created_at",                                          null: false
    t.datetime "updated_at",                                          null: false
    t.decimal  "gross_kgs",                  precision: 9,  scale: 2
    t.decimal  "cbms",                       precision: 9,  scale: 5
    t.integer  "carton_qty",     limit: 4
    t.integer  "carton_set_id",  limit: 4
    t.integer  "order_id",       limit: 4
    t.integer  "order_line_id",  limit: 4
    t.string   "container_size", limit: 255
    t.integer  "variant_id",     limit: 4
  end

  add_index "booking_lines", ["order_id", "order_line_id"], name: "index_booking_lines_on_order_id_and_order_line_id", using: :btree
  add_index "booking_lines", ["order_line_id"], name: "index_booking_lines_on_order_line_id", using: :btree
  add_index "booking_lines", ["product_id"], name: "index_booking_lines_on_product_id", using: :btree
  add_index "booking_lines", ["shipment_id"], name: "index_booking_lines_on_shipment_id", using: :btree
  add_index "booking_lines", ["variant_id"], name: "index_booking_lines_on_variant_id", using: :btree

  create_table "broker_invoice_lines", force: :cascade do |t|
    t.integer  "broker_invoice_id",  limit: 4
    t.string   "charge_code",        limit: 255
    t.string   "charge_description", limit: 255
    t.decimal  "charge_amount",                  precision: 11, scale: 2
    t.string   "vendor_name",        limit: 255
    t.string   "vendor_reference",   limit: 255
    t.string   "charge_type",        limit: 255
    t.datetime "created_at",                                              null: false
    t.datetime "updated_at",                                              null: false
    t.decimal  "hst_percent",                    precision: 4,  scale: 3
  end

  add_index "broker_invoice_lines", ["broker_invoice_id"], name: "index_broker_invoice_lines_on_broker_invoice_id", using: :btree
  add_index "broker_invoice_lines", ["charge_code"], name: "index_broker_invoice_lines_on_charge_code", using: :btree

  create_table "broker_invoices", force: :cascade do |t|
    t.integer  "entry_id",             limit: 4
    t.string   "suffix",               limit: 255
    t.date     "invoice_date"
    t.string   "customer_number",      limit: 255
    t.decimal  "invoice_total",                    precision: 11, scale: 2
    t.string   "bill_to_name",         limit: 255
    t.string   "bill_to_address_1",    limit: 255
    t.string   "bill_to_address_2",    limit: 255
    t.string   "bill_to_city",         limit: 255
    t.string   "bill_to_state",        limit: 255
    t.string   "bill_to_zip",          limit: 255
    t.integer  "bill_to_country_id",   limit: 4
    t.datetime "created_at",                                                null: false
    t.datetime "updated_at",                                                null: false
    t.boolean  "locked"
    t.string   "currency",             limit: 255
    t.string   "invoice_number",       limit: 255
    t.string   "source_system",        limit: 255
    t.string   "broker_reference",     limit: 255
    t.string   "last_file_bucket",     limit: 255
    t.string   "last_file_path",       limit: 255
    t.integer  "summary_statement_id", limit: 4
    t.date     "fiscal_date"
    t.integer  "fiscal_month",         limit: 4
    t.integer  "fiscal_year",          limit: 4
  end

  add_index "broker_invoices", ["broker_reference", "source_system"], name: "index_broker_invoices_on_broker_reference_and_source_system", using: :btree
  add_index "broker_invoices", ["customer_number"], name: "index_broker_invoices_on_customer_number", using: :btree
  add_index "broker_invoices", ["entry_id"], name: "index_broker_invoices_on_entry_id", using: :btree
  add_index "broker_invoices", ["invoice_date"], name: "index_broker_invoices_on_invoice_date", using: :btree
  add_index "broker_invoices", ["invoice_number"], name: "index_broker_invoices_on_invoice_number", using: :btree
  add_index "broker_invoices", ["summary_statement_id"], name: "index_broker_invoices_on_summary_statement_id", using: :btree

  create_table "bulk_process_logs", force: :cascade do |t|
    t.integer  "user_id",              limit: 4
    t.string   "bulk_type",            limit: 255
    t.datetime "started_at"
    t.datetime "finished_at"
    t.integer  "total_object_count",   limit: 4
    t.integer  "changed_object_count", limit: 4
    t.datetime "created_at",                       null: false
    t.datetime "updated_at",                       null: false
  end

  create_table "business_rule_snapshots", force: :cascade do |t|
    t.integer  "recordable_id",   limit: 4,   null: false
    t.string   "recordable_type", limit: 255, null: false
    t.string   "bucket",          limit: 255
    t.string   "doc_path",        limit: 255
    t.string   "version",         limit: 255
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
    t.datetime "compared_at"
  end

  add_index "business_rule_snapshots", ["recordable_id", "recordable_type"], name: "business_rule_snapshots_on_recordable_id_and_recordable_type", using: :btree

  create_table "business_validation_results", force: :cascade do |t|
    t.integer  "business_validation_template_id", limit: 4
    t.integer  "validatable_id",                  limit: 4
    t.string   "validatable_type",                limit: 255
    t.string   "state",                           limit: 255
    t.datetime "created_at",                                  null: false
    t.datetime "updated_at",                                  null: false
  end

  add_index "business_validation_results", ["business_validation_template_id"], name: "business_validation_template", using: :btree
  add_index "business_validation_results", ["validatable_id", "validatable_type"], name: "validatable", using: :btree

  create_table "business_validation_rule_results", force: :cascade do |t|
    t.integer  "business_validation_result_id", limit: 4
    t.integer  "business_validation_rule_id",   limit: 4
    t.string   "state",                         limit: 255
    t.text     "message",                       limit: 65535
    t.text     "note",                          limit: 65535
    t.integer  "overridden_by_id",              limit: 4
    t.datetime "overridden_at"
    t.datetime "created_at",                                  null: false
    t.datetime "updated_at",                                  null: false
  end

  add_index "business_validation_rule_results", ["business_validation_result_id"], name: "business_validation_result", using: :btree
  add_index "business_validation_rule_results", ["business_validation_rule_id"], name: "business_validation_rule", using: :btree
  add_index "business_validation_rule_results", ["overridden_by_id"], name: "index_business_validation_rule_results_on_overridden_by_id", using: :btree

  create_table "business_validation_rules", force: :cascade do |t|
    t.integer  "business_validation_template_id", limit: 4
    t.string   "type",                            limit: 255
    t.string   "name",                            limit: 255
    t.string   "description",                     limit: 255
    t.string   "fail_state",                      limit: 255
    t.text     "rule_attributes_json",            limit: 65535
    t.datetime "created_at",                                    null: false
    t.datetime "updated_at",                                    null: false
    t.integer  "group_id",                        limit: 4
    t.boolean  "delete_pending"
    t.string   "notification_type",               limit: 255
    t.text     "notification_recipients",         limit: 65535
    t.boolean  "disabled"
    t.boolean  "suppress_pass_notice"
    t.boolean  "suppress_review_fail_notice"
    t.boolean  "suppress_skipped_notice"
    t.string   "subject_pass",                    limit: 255
    t.string   "subject_review_fail",             limit: 255
    t.string   "subject_skipped",                 limit: 255
    t.string   "message_pass",                    limit: 255
    t.string   "message_review_fail",             limit: 255
    t.string   "message_skipped",                 limit: 255
    t.integer  "mailing_list_id",                 limit: 4
    t.text     "bcc_notification_recipients",     limit: 65535
    t.text     "cc_notification_recipients",      limit: 65535
  end

  add_index "business_validation_rules", ["business_validation_template_id"], name: "template_id", using: :btree

  create_table "business_validation_scheduled_jobs", force: :cascade do |t|
    t.integer  "business_validation_schedule_id", limit: 4
    t.integer  "validatable_id",                  limit: 4
    t.string   "validatable_type",                limit: 255
    t.datetime "run_date"
    t.datetime "created_at",                                  null: false
    t.datetime "updated_at",                                  null: false
  end

  create_table "business_validation_schedules", force: :cascade do |t|
    t.string   "module_type",     limit: 255
    t.string   "model_field_uid", limit: 255
    t.string   "operator",        limit: 255
    t.integer  "num_days",        limit: 4
    t.string   "name",            limit: 255
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
  end

  create_table "business_validation_templates", force: :cascade do |t|
    t.string   "name",           limit: 255
    t.string   "module_type",    limit: 255, null: false
    t.string   "description",    limit: 255
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
    t.boolean  "delete_pending"
    t.boolean  "disabled"
    t.boolean  "private"
    t.string   "system_code",    limit: 255
  end

  create_table "calendar_events", force: :cascade do |t|
    t.date     "event_date"
    t.string   "label",       limit: 255
    t.integer  "calendar_id", limit: 4
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "calendars", force: :cascade do |t|
    t.string   "calendar_type", limit: 255
    t.integer  "year",          limit: 2
    t.integer  "company_id",    limit: 4
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "canadian_pga_line_ingredients", force: :cascade do |t|
    t.integer  "canadian_pga_line_id", limit: 4
    t.string   "name",                 limit: 255
    t.decimal  "quality",                          precision: 13, scale: 4
    t.decimal  "quantity",                         precision: 13, scale: 4
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "canadian_pga_lines", force: :cascade do |t|
    t.string   "agency_code",                limit: 255
    t.integer  "commercial_invoice_line_id", limit: 4
    t.string   "batch_lot_number",           limit: 255
    t.string   "brand_name",                 limit: 255
    t.string   "commodity_type",             limit: 255
    t.string   "country_of_origin",          limit: 255
    t.string   "exception_processes",        limit: 255
    t.datetime "expiry_date"
    t.string   "fda_product_code",           limit: 255
    t.string   "file_name",                  limit: 255
    t.string   "gtin",                       limit: 255
    t.string   "importer_contact_name",      limit: 255
    t.string   "importer_contact_email",     limit: 255
    t.string   "importer_contact_phone",     limit: 255
    t.string   "intended_use_code",          limit: 255
    t.string   "lpco_number",                limit: 255
    t.string   "lpco_type",                  limit: 255
    t.datetime "manufacture_date"
    t.string   "model_designation",          limit: 255
    t.string   "model_label",                limit: 255
    t.string   "model_number",               limit: 255
    t.string   "product_name",               limit: 255
    t.string   "program_code",               limit: 255
    t.string   "purpose",                    limit: 255
    t.string   "state_of_origin",            limit: 255
    t.string   "unique_device_identifier",   limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "carton_sets", force: :cascade do |t|
    t.integer  "starting_carton", limit: 4
    t.integer  "carton_qty",      limit: 4
    t.decimal  "length_cm",                 precision: 8, scale: 4
    t.decimal  "width_cm",                  precision: 8, scale: 4
    t.decimal  "height_cm",                 precision: 8, scale: 4
    t.decimal  "net_net_kgs",               precision: 8, scale: 4
    t.decimal  "net_kgs",                   precision: 8, scale: 4
    t.decimal  "gross_kgs",                 precision: 8, scale: 4
    t.integer  "shipment_id",     limit: 4
    t.datetime "created_at",                                        null: false
    t.datetime "updated_at",                                        null: false
  end

  add_index "carton_sets", ["shipment_id"], name: "index_carton_sets_on_shipment_id", using: :btree

  create_table "change_record_messages", force: :cascade do |t|
    t.integer  "change_record_id", limit: 4
    t.string   "message",          limit: 255
    t.datetime "created_at",                   null: false
    t.datetime "updated_at",                   null: false
  end

  add_index "change_record_messages", ["change_record_id"], name: "index_change_record_messages_on_change_record_id", using: :btree

  create_table "change_records", force: :cascade do |t|
    t.integer  "file_import_result_id",  limit: 4
    t.integer  "recordable_id",          limit: 4
    t.string   "recordable_type",        limit: 255
    t.integer  "record_sequence_number", limit: 4
    t.datetime "created_at",                         null: false
    t.datetime "updated_at",                         null: false
    t.boolean  "failed"
    t.integer  "bulk_process_log_id",    limit: 4
    t.string   "unique_identifier",      limit: 255
  end

  add_index "change_records", ["bulk_process_log_id"], name: "index_change_records_on_bulk_process_log_id", using: :btree
  add_index "change_records", ["file_import_result_id"], name: "index_change_records_on_file_import_result_id", using: :btree

  create_table "charge_categories", force: :cascade do |t|
    t.integer  "company_id",  limit: 4
    t.string   "charge_code", limit: 255
    t.string   "category",    limit: 255
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
  end

  add_index "charge_categories", ["company_id"], name: "index_charge_categories_on_company_id", using: :btree

  create_table "charge_codes", force: :cascade do |t|
    t.string   "code",        limit: 255
    t.string   "description", limit: 255
    t.boolean  "apply_hst"
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
  end

  create_table "classifications", force: :cascade do |t|
    t.integer  "country_id",                limit: 4
    t.integer  "product_id",                limit: 4
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
    t.integer  "instant_classification_id", limit: 4
  end

  add_index "classifications", ["country_id"], name: "index_classifications_on_country_id", using: :btree
  add_index "classifications", ["product_id"], name: "index_classifications_on_product_id", using: :btree

  create_table "comments", force: :cascade do |t|
    t.text     "body",             limit: 65535
    t.string   "subject",          limit: 255
    t.integer  "user_id",          limit: 4
    t.integer  "commentable_id",   limit: 4
    t.string   "commentable_type", limit: 255
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
  end

  add_index "comments", ["commentable_id", "commentable_type"], name: "index_comments_on_commentable_id_and_commentable_type", using: :btree

  create_table "commercial_invoice_lacey_components", force: :cascade do |t|
    t.integer "line_number",                  limit: 4
    t.string  "detailed_description",         limit: 255
    t.decimal "value",                                    precision: 9,  scale: 2
    t.string  "name",                         limit: 255
    t.decimal "quantity",                                 precision: 12, scale: 3
    t.string  "unit_of_measure",              limit: 255
    t.string  "genus",                        limit: 255
    t.string  "species",                      limit: 255
    t.string  "harvested_from_country",       limit: 255
    t.decimal "percent_recycled_material",                precision: 5,  scale: 2
    t.string  "container_numbers",            limit: 255
    t.integer "commercial_invoice_tariff_id", limit: 4,                            null: false
  end

  add_index "commercial_invoice_lacey_components", ["commercial_invoice_tariff_id"], name: "lacey_components_by_tariff_id", using: :btree

  create_table "commercial_invoice_lines", force: :cascade do |t|
    t.string   "part_number",                limit: 255
    t.integer  "line_number",                limit: 4
    t.string   "po_number",                  limit: 255
    t.string   "unit_of_measure",            limit: 255
    t.integer  "commercial_invoice_id",      limit: 4
    t.datetime "created_at",                                                      null: false
    t.datetime "updated_at",                                                      null: false
    t.decimal  "value",                                  precision: 11, scale: 2
    t.decimal  "drawback_qty",                           precision: 11, scale: 2
    t.decimal  "quantity",                               precision: 12, scale: 3
    t.string   "mid",                        limit: 255
    t.string   "country_origin_code",        limit: 255
    t.decimal  "charges",                                precision: 11, scale: 2
    t.string   "country_export_code",        limit: 255
    t.boolean  "related_parties"
    t.string   "vendor_name",                limit: 255
    t.decimal  "volume",                                 precision: 11, scale: 2
    t.decimal  "computed_value",                         precision: 13, scale: 2
    t.decimal  "computed_adjustments",                   precision: 13, scale: 2
    t.decimal  "computed_net_value",                     precision: 13, scale: 2
    t.decimal  "mpf",                                    precision: 11, scale: 2
    t.decimal  "hmf",                                    precision: 11, scale: 2
    t.decimal  "cotton_fee",                             precision: 11, scale: 2
    t.string   "state_export_code",          limit: 255
    t.string   "state_origin_code",          limit: 255
    t.decimal  "unit_price",                             precision: 12, scale: 3
    t.string   "department",                 limit: 255
    t.decimal  "prorated_mpf",                           precision: 11, scale: 2
    t.decimal  "contract_amount",                        precision: 12, scale: 2
    t.string   "add_case_number",            limit: 255
    t.boolean  "add_bond"
    t.decimal  "add_duty_amount",                        precision: 12, scale: 2
    t.decimal  "add_case_value",                         precision: 12, scale: 2
    t.decimal  "add_case_percent",                       precision: 5,  scale: 2
    t.string   "cvd_case_number",            limit: 255
    t.boolean  "cvd_bond"
    t.decimal  "cvd_duty_amount",                        precision: 12, scale: 2
    t.decimal  "cvd_case_value",                         precision: 12, scale: 2
    t.decimal  "cvd_case_percent",                       precision: 5,  scale: 2
    t.string   "customer_reference",         limit: 255
    t.decimal  "adjustments_amount",                     precision: 12, scale: 3
    t.decimal  "value_foreign",                          precision: 11, scale: 2
    t.string   "currency",                   limit: 255
    t.integer  "customs_line_number",        limit: 4
    t.string   "product_line",               limit: 255
    t.string   "visa_number",                limit: 255
    t.decimal  "visa_quantity",                          precision: 12, scale: 3
    t.string   "visa_uom",                   limit: 255
    t.string   "store_name",                 limit: 255
    t.integer  "subheader_number",           limit: 4
    t.integer  "container_id",               limit: 4
    t.datetime "fda_review_date"
    t.datetime "fda_hold_date"
    t.datetime "fda_release_date"
    t.boolean  "first_sale"
    t.string   "value_appraisal_method",     limit: 255
    t.decimal  "non_dutiable_amount",                    precision: 13, scale: 2
    t.decimal  "other_fees",                             precision: 11, scale: 2
    t.decimal  "miscellaneous_discount",                 precision: 12, scale: 2
    t.decimal  "freight_amount",                         precision: 12, scale: 2
    t.decimal  "other_amount",                           precision: 12, scale: 2
    t.decimal  "cash_discount",                          precision: 12, scale: 2
    t.decimal  "add_to_make_amount",                     precision: 12, scale: 2
    t.string   "agriculture_license_number", limit: 255
    t.string   "psc_reason_code",            limit: 255
    t.datetime "psc_date"
    t.integer  "entered_value_7501",         limit: 4
    t.string   "ruling_number",              limit: 255
    t.string   "ruling_type",                limit: 255
    t.decimal  "hmf_rate",                               precision: 14, scale: 8
    t.decimal  "mpf_rate",                               precision: 14, scale: 8
    t.decimal  "cotton_fee_rate",                        precision: 14, scale: 8
  end

  add_index "commercial_invoice_lines", ["commercial_invoice_id"], name: "index_commercial_invoice_lines_on_commercial_invoice_id", using: :btree
  add_index "commercial_invoice_lines", ["container_id"], name: "index_commercial_invoice_lines_on_container_id", using: :btree
  add_index "commercial_invoice_lines", ["part_number"], name: "index_commercial_invoice_lines_on_part_number", using: :btree

  create_table "commercial_invoice_maps", force: :cascade do |t|
    t.string   "source_mfid",      limit: 255
    t.string   "destination_mfid", limit: 255
    t.datetime "created_at",                   null: false
    t.datetime "updated_at",                   null: false
  end

  create_table "commercial_invoice_tariffs", force: :cascade do |t|
    t.integer  "commercial_invoice_line_id", limit: 4
    t.string   "hts_code",                   limit: 255
    t.decimal  "duty_amount",                            precision: 12, scale: 2
    t.decimal  "entered_value",                          precision: 13, scale: 2
    t.string   "spi_primary",                limit: 255
    t.string   "spi_secondary",              limit: 255
    t.decimal  "classification_qty_1",                   precision: 12, scale: 2
    t.string   "classification_uom_1",       limit: 255
    t.decimal  "classification_qty_2",                   precision: 12, scale: 2
    t.string   "classification_uom_2",       limit: 255
    t.decimal  "classification_qty_3",                   precision: 12, scale: 2
    t.string   "classification_uom_3",       limit: 255
    t.integer  "gross_weight",               limit: 4
    t.integer  "integer",                    limit: 4
    t.string   "tariff_description",         limit: 255
    t.datetime "created_at",                                                      null: false
    t.datetime "updated_at",                                                      null: false
    t.string   "tariff_provision",           limit: 255
    t.string   "value_for_duty_code",        limit: 255
    t.string   "gst_rate_code",              limit: 255
    t.decimal  "gst_amount",                             precision: 11, scale: 2
    t.decimal  "sima_amount",                            precision: 11, scale: 2
    t.decimal  "excise_amount",                          precision: 11, scale: 2
    t.string   "excise_rate_code",           limit: 255
    t.decimal  "duty_rate",                              precision: 4,  scale: 3
    t.integer  "quota_category",             limit: 4
    t.string   "special_authority",          limit: 255
    t.string   "sima_code",                  limit: 255
    t.integer  "entered_value_7501",         limit: 4
    t.boolean  "special_tariff"
    t.decimal  "duty_advalorem",                         precision: 12, scale: 2
    t.decimal  "duty_specific",                          precision: 12, scale: 2
    t.decimal  "duty_additional",                        precision: 12, scale: 2
    t.decimal  "duty_other",                             precision: 12, scale: 2
    t.decimal  "advalorem_rate",                         precision: 14, scale: 7
    t.decimal  "specific_rate",                          precision: 14, scale: 7
    t.string   "specific_rate_uom",          limit: 255
    t.decimal  "additional_rate",                        precision: 14, scale: 7
    t.string   "additional_rate_uom",        limit: 255
    t.string   "duty_rate_description",      limit: 255
  end

  add_index "commercial_invoice_tariffs", ["commercial_invoice_line_id"], name: "index_commercial_invoice_tariffs_on_commercial_invoice_line_id", using: :btree
  add_index "commercial_invoice_tariffs", ["hts_code"], name: "index_commercial_invoice_tariffs_on_hts_code", using: :btree

  create_table "commercial_invoices", force: :cascade do |t|
    t.string   "invoice_number",         limit: 255
    t.string   "vendor_name",            limit: 255
    t.integer  "entry_id",               limit: 4
    t.datetime "created_at",                                                    null: false
    t.datetime "updated_at",                                                    null: false
    t.string   "currency",               limit: 255
    t.decimal  "exchange_rate",                        precision: 8,  scale: 6
    t.decimal  "invoice_value_foreign",                precision: 13, scale: 2
    t.decimal  "invoice_value",                        precision: 13, scale: 2
    t.string   "country_origin_code",    limit: 255
    t.integer  "gross_weight",           limit: 4
    t.decimal  "total_charges",                        precision: 11, scale: 2
    t.date     "invoice_date"
    t.string   "mfid",                   limit: 255
    t.integer  "vendor_id",              limit: 4
    t.integer  "importer_id",            limit: 4
    t.integer  "consignee_id",           limit: 4
    t.decimal  "total_quantity",                       precision: 12, scale: 5
    t.string   "total_quantity_uom",     limit: 255
    t.date     "docs_received_date"
    t.date     "docs_ok_date"
    t.string   "issue_codes",            limit: 255
    t.text     "rater_comments",         limit: 65535
    t.string   "destination_code",       limit: 255
    t.decimal  "non_dutiable_amount",                  precision: 13, scale: 2
    t.text     "master_bills_of_lading", limit: 65535
    t.text     "house_bills_of_lading",  limit: 65535
    t.integer  "entered_value_7501",     limit: 4
    t.string   "customer_reference",     limit: 255
    t.decimal  "net_weight",                           precision: 11, scale: 2
  end

  add_index "commercial_invoices", ["entry_id"], name: "index_commercial_invoices_on_entry_id", using: :btree
  add_index "commercial_invoices", ["importer_id"], name: "index_commercial_invoices_on_importer_id", using: :btree
  add_index "commercial_invoices", ["invoice_date"], name: "index_commercial_invoices_on_invoice_date", using: :btree
  add_index "commercial_invoices", ["invoice_number"], name: "index_commercial_invoices_on_invoice_number", using: :btree

  create_table "companies", force: :cascade do |t|
    t.string   "name",                          limit: 255
    t.boolean  "carrier"
    t.boolean  "vendor"
    t.boolean  "master"
    t.datetime "created_at",                                                null: false
    t.datetime "updated_at",                                                null: false
    t.boolean  "locked"
    t.boolean  "customer"
    t.string   "system_code",                   limit: 255
    t.boolean  "importer"
    t.string   "alliance_customer_number",      limit: 255
    t.boolean  "broker"
    t.string   "fenix_customer_number",         limit: 255
    t.boolean  "drawback"
    t.datetime "last_alliance_product_push_at"
    t.string   "name_2",                        limit: 255
    t.boolean  "consignee"
    t.string   "ecellerate_customer_number",    limit: 255
    t.boolean  "agent"
    t.boolean  "factory"
    t.string   "enabled_booking_types",         limit: 255
    t.string   "irs_number",                    limit: 255
    t.boolean  "show_business_rules"
    t.string   "slack_channel",                 limit: 255
    t.boolean  "forwarder"
    t.string   "mid",                           limit: 255
    t.string   "ticketing_system_code",         limit: 255
    t.string   "fiscal_reference",              limit: 255
    t.boolean  "selling_agent"
    t.boolean  "drawback_customer",                         default: false, null: false
  end

  add_index "companies", ["agent"], name: "index_companies_on_agent", using: :btree
  add_index "companies", ["alliance_customer_number"], name: "index_companies_on_alliance_customer_number", using: :btree
  add_index "companies", ["carrier"], name: "index_companies_on_carrier", using: :btree
  add_index "companies", ["customer"], name: "index_companies_on_customer", using: :btree
  add_index "companies", ["drawback"], name: "index_companies_on_drawback", using: :btree
  add_index "companies", ["ecellerate_customer_number"], name: "index_companies_on_ecellerate_customer_number", using: :btree
  add_index "companies", ["factory"], name: "index_companies_on_factory", using: :btree
  add_index "companies", ["fenix_customer_number"], name: "index_companies_on_fenix_customer_number", using: :btree
  add_index "companies", ["master"], name: "index_companies_on_master", using: :btree
  add_index "companies", ["system_code"], name: "index_companies_on_system_code", using: :btree
  add_index "companies", ["vendor"], name: "index_companies_on_vendor", using: :btree

  create_table "constant_texts", force: :cascade do |t|
    t.string   "text_type",              limit: 255, null: false
    t.string   "constant_text",          limit: 255, null: false
    t.date     "effective_date_start",               null: false
    t.date     "effective_date_end"
    t.integer  "constant_textable_id",   limit: 4,   null: false
    t.string   "constant_textable_type", limit: 255, null: false
    t.datetime "created_at",                         null: false
    t.datetime "updated_at",                         null: false
  end

  add_index "constant_texts", ["constant_textable_id", "constant_textable_type"], name: "idx_constant_textable_id_and_constant_textable_type", using: :btree

  create_table "containers", force: :cascade do |t|
    t.string   "container_number",          limit: 255
    t.string   "container_size",            limit: 255
    t.string   "size_description",          limit: 255
    t.integer  "weight",                    limit: 4
    t.integer  "quantity",                  limit: 4
    t.string   "uom",                       limit: 255
    t.string   "goods_description",         limit: 255
    t.string   "seal_number",               limit: 255
    t.integer  "teus",                      limit: 4
    t.string   "fcl_lcl",                   limit: 255
    t.integer  "entry_id",                  limit: 4
    t.datetime "created_at",                            null: false
    t.datetime "updated_at",                            null: false
    t.integer  "shipment_id",               limit: 4
    t.date     "container_pickup_date"
    t.date     "container_return_date"
    t.integer  "port_of_loading_id",        limit: 4
    t.integer  "port_of_delivery_id",       limit: 4
    t.datetime "last_exported_from_source"
  end

  add_index "containers", ["entry_id"], name: "index_containers_on_entry_id", using: :btree
  add_index "containers", ["shipment_id"], name: "index_containers_on_shipment_id", using: :btree

  create_table "corrective_action_plans", force: :cascade do |t|
    t.integer  "survey_response_id", limit: 4
    t.integer  "created_by_id",      limit: 4
    t.string   "status",             limit: 255
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
  end

  add_index "corrective_action_plans", ["created_by_id"], name: "index_corrective_action_plans_on_created_by_id", using: :btree
  add_index "corrective_action_plans", ["survey_response_id"], name: "index_corrective_action_plans_on_survey_response_id", using: :btree

  create_table "corrective_issues", force: :cascade do |t|
    t.integer  "corrective_action_plan_id", limit: 4
    t.text     "description",               limit: 65535
    t.text     "suggested_action",          limit: 65535
    t.string   "action_taken",              limit: 255
    t.datetime "created_at",                              null: false
    t.datetime "updated_at",                              null: false
    t.boolean  "resolved"
  end

  add_index "corrective_issues", ["corrective_action_plan_id"], name: "index_corrective_issues_on_corrective_action_plan_id", using: :btree

  create_table "countries", force: :cascade do |t|
    t.string   "name",                limit: 255
    t.string   "iso_code",            limit: 2
    t.datetime "created_at",                      null: false
    t.datetime "updated_at",                      null: false
    t.boolean  "import_location"
    t.integer  "classification_rank", limit: 4
    t.boolean  "european_union"
    t.boolean  "quicksearch_show"
    t.string   "iso_3_code",          limit: 255
    t.boolean  "active_origin"
  end

  add_index "countries", ["iso_3_code"], name: "index_countries_on_iso_3_code", using: :btree

  create_table "countries_regions", force: :cascade do |t|
    t.integer "country_id", limit: 4
    t.integer "region_id",  limit: 4
  end

  add_index "countries_regions", ["country_id"], name: "index_countries_regions_on_country_id", using: :btree
  add_index "countries_regions", ["region_id", "country_id"], name: "index_countries_regions_on_region_id_and_country_id", unique: true, using: :btree

  create_table "custom_definitions", force: :cascade do |t|
    t.string   "label",                limit: 255
    t.string   "data_type",            limit: 255
    t.integer  "rank",                 limit: 4
    t.string   "module_type",          limit: 255
    t.datetime "created_at",                         null: false
    t.datetime "updated_at",                         null: false
    t.string   "tool_tip",             limit: 255
    t.string   "default_value",        limit: 255
    t.boolean  "quick_searchable"
    t.text     "definition",           limit: 65535
    t.boolean  "is_user"
    t.boolean  "is_address"
    t.string   "cdef_uid",             limit: 255
    t.text     "virtual_search_query", limit: 65535
    t.text     "virtual_value_query",  limit: 65535
  end

  add_index "custom_definitions", ["cdef_uid"], name: "index_custom_definitions_on_cdef_uid", unique: true, using: :btree
  add_index "custom_definitions", ["module_type"], name: "index_custom_definitions_on_module_type", using: :btree

  create_table "custom_file_records", force: :cascade do |t|
    t.string   "linked_object_type", limit: 255
    t.integer  "linked_object_id",   limit: 4
    t.integer  "custom_file_id",     limit: 4
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
  end

  add_index "custom_file_records", ["custom_file_id"], name: "cf_id", using: :btree
  add_index "custom_file_records", ["linked_object_id", "linked_object_type"], name: "linked_objects", using: :btree

  create_table "custom_files", force: :cascade do |t|
    t.integer  "uploaded_by_id",        limit: 4
    t.string   "file_type",             limit: 255
    t.string   "attached_content_type", limit: 255
    t.integer  "attached_file_size",    limit: 4
    t.datetime "attached_updated_at"
    t.string   "attached_file_name",    limit: 255
    t.datetime "created_at",                        null: false
    t.datetime "updated_at",                        null: false
    t.string   "module_type",           limit: 255
    t.datetime "start_at"
    t.datetime "finish_at"
    t.datetime "error_at"
    t.string   "error_message",         limit: 255
  end

  add_index "custom_files", ["file_type"], name: "ftype", using: :btree

  create_table "custom_reports", force: :cascade do |t|
    t.string   "name",               limit: 255
    t.integer  "user_id",            limit: 4
    t.string   "type",               limit: 255
    t.boolean  "include_links"
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
    t.boolean  "no_time"
    t.boolean  "include_rule_links"
  end

  add_index "custom_reports", ["type"], name: "index_custom_reports_on_type", using: :btree
  add_index "custom_reports", ["user_id"], name: "index_custom_reports_on_user_id", using: :btree

  create_table "custom_values", force: :cascade do |t|
    t.integer  "customizable_id",      limit: 4,                              null: false
    t.string   "customizable_type",    limit: 255,                            null: false
    t.string   "string_value",         limit: 255
    t.decimal  "decimal_value",                      precision: 13, scale: 4
    t.integer  "integer_value",        limit: 4
    t.date     "date_value"
    t.integer  "custom_definition_id", limit: 4
    t.datetime "created_at",                                                  null: false
    t.datetime "updated_at",                                                  null: false
    t.text     "text_value",           limit: 65535
    t.boolean  "boolean_value"
    t.datetime "datetime_value"
  end

  add_index "custom_values", ["boolean_value"], name: "index_custom_values_on_boolean_value", using: :btree
  add_index "custom_values", ["custom_definition_id"], name: "index_custom_values_on_custom_definition_id", using: :btree
  add_index "custom_values", ["customizable_id", "customizable_type", "custom_definition_id"], name: "cv_unique_composite", unique: true, using: :btree
  add_index "custom_values", ["customizable_id", "customizable_type"], name: "index_custom_values_on_customizable_id_and_customizable_type", using: :btree
  add_index "custom_values", ["date_value"], name: "index_custom_values_on_date_value", using: :btree
  add_index "custom_values", ["datetime_value"], name: "index_custom_values_on_datetime_value", using: :btree
  add_index "custom_values", ["decimal_value"], name: "index_custom_values_on_decimal_value", using: :btree
  add_index "custom_values", ["integer_value"], name: "index_custom_values_on_integer_value", using: :btree
  add_index "custom_values", ["string_value"], name: "index_custom_values_on_string_value", using: :btree
  add_index "custom_values", ["text_value"], name: "index_custom_values_on_text_value", length: {"text_value"=>64}, using: :btree

  create_table "custom_view_templates", force: :cascade do |t|
    t.string   "template_identifier", limit: 255
    t.string   "template_path",       limit: 255
    t.datetime "created_at",                      null: false
    t.datetime "updated_at",                      null: false
    t.string   "module_type",         limit: 255
  end

  add_index "custom_view_templates", ["template_identifier"], name: "index_custom_view_templates_on_template_identifier", using: :btree

  create_table "daily_statement_entries", force: :cascade do |t|
    t.integer  "daily_statement_id",          limit: 4
    t.string   "broker_reference",            limit: 255
    t.integer  "entry_id",                    limit: 4
    t.string   "port_code",                   limit: 255
    t.decimal  "duty_amount",                             precision: 11, scale: 2
    t.decimal  "preliminary_duty_amount",                 precision: 11, scale: 2
    t.decimal  "tax_amount",                              precision: 11, scale: 2
    t.decimal  "preliminary_tax_amount",                  precision: 11, scale: 2
    t.decimal  "cvd_amount",                              precision: 11, scale: 2
    t.decimal  "preliminary_cvd_amount",                  precision: 11, scale: 2
    t.decimal  "add_amount",                              precision: 11, scale: 2
    t.decimal  "preliminary_add_amount",                  precision: 11, scale: 2
    t.decimal  "fee_amount",                              precision: 11, scale: 2
    t.decimal  "preliminary_fee_amount",                  precision: 11, scale: 2
    t.decimal  "interest_amount",                         precision: 11, scale: 2
    t.decimal  "preliminary_interest_amount",             precision: 11, scale: 2
    t.decimal  "total_amount",                            precision: 11, scale: 2
    t.decimal  "preliminary_total_amount",                precision: 11, scale: 2
    t.decimal  "billed_amount",                           precision: 11, scale: 2
    t.datetime "created_at",                                                       null: false
    t.datetime "updated_at",                                                       null: false
  end

  add_index "daily_statement_entries", ["broker_reference"], name: "index_daily_statement_entries_on_broker_reference", using: :btree
  add_index "daily_statement_entries", ["daily_statement_id"], name: "index_daily_statement_entries_on_daily_statement_id", using: :btree
  add_index "daily_statement_entries", ["entry_id"], name: "index_daily_statement_entries_on_entry_id", using: :btree

  create_table "daily_statement_entry_fees", force: :cascade do |t|
    t.integer "daily_statement_entry_id", limit: 4
    t.string  "code",                     limit: 255
    t.string  "description",              limit: 255
    t.decimal "amount",                               precision: 11, scale: 2
    t.decimal "preliminary_amount",                   precision: 11, scale: 2
  end

  add_index "daily_statement_entry_fees", ["daily_statement_entry_id"], name: "index_daily_statement_entry_fees_on_daily_statement_entry_id", using: :btree

  create_table "daily_statements", force: :cascade do |t|
    t.string   "statement_number",            limit: 255
    t.string   "monthly_statement_number",    limit: 255
    t.integer  "monthly_statement_id",        limit: 4
    t.string   "status",                      limit: 255
    t.date     "received_date"
    t.date     "final_received_date"
    t.date     "due_date"
    t.date     "paid_date"
    t.date     "payment_accepted_date"
    t.string   "port_code",                   limit: 255
    t.string   "pay_type",                    limit: 255
    t.string   "customer_number",             limit: 255
    t.integer  "importer_id",                 limit: 4
    t.decimal  "total_amount",                            precision: 11, scale: 2
    t.decimal  "preliminary_total_amount",                precision: 11, scale: 2
    t.decimal  "duty_amount",                             precision: 11, scale: 2
    t.decimal  "preliminary_duty_amount",                 precision: 11, scale: 2
    t.decimal  "tax_amount",                              precision: 11, scale: 2
    t.decimal  "preliminary_tax_amount",                  precision: 11, scale: 2
    t.decimal  "cvd_amount",                              precision: 11, scale: 2
    t.decimal  "preliminary_cvd_amount",                  precision: 11, scale: 2
    t.decimal  "add_amount",                              precision: 11, scale: 2
    t.decimal  "preliminary_add_amount",                  precision: 11, scale: 2
    t.decimal  "interest_amount",                         precision: 11, scale: 2
    t.decimal  "preliminary_interest_amount",             precision: 11, scale: 2
    t.decimal  "fee_amount",                              precision: 11, scale: 2
    t.decimal  "preliminary_fee_amount",                  precision: 11, scale: 2
    t.string   "last_file_bucket",            limit: 255
    t.string   "last_file_path",              limit: 255
    t.datetime "last_exported_from_source"
    t.datetime "created_at",                                                       null: false
    t.datetime "updated_at",                                                       null: false
  end

  add_index "daily_statements", ["importer_id"], name: "index_daily_statements_on_importer_id", using: :btree
  add_index "daily_statements", ["monthly_statement_id"], name: "index_daily_statements_on_monthly_statement_id", using: :btree
  add_index "daily_statements", ["monthly_statement_number"], name: "index_daily_statements_on_monthly_statement_number", using: :btree
  add_index "daily_statements", ["statement_number"], name: "index_daily_statements_on_statement_number", unique: true, using: :btree

  create_table "dashboard_widgets", force: :cascade do |t|
    t.integer  "user_id",         limit: 4
    t.integer  "search_setup_id", limit: 4
    t.integer  "rank",            limit: 4
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
  end

  add_index "dashboard_widgets", ["user_id"], name: "index_dashboard_widgets_on_user_id", using: :btree

  create_table "data_cross_references", force: :cascade do |t|
    t.string   "key",                  limit: 255
    t.string   "value",                limit: 255
    t.string   "cross_reference_type", limit: 255
    t.integer  "company_id",           limit: 4
    t.datetime "created_at",                       null: false
    t.datetime "updated_at",                       null: false
  end

  add_index "data_cross_references", ["cross_reference_type", "value"], name: "index_data_cross_references_on_cross_reference_type_and_value", using: :btree
  add_index "data_cross_references", ["key", "cross_reference_type", "company_id"], name: "index_data_xref_on_key_and_xref_type_and_company_id", unique: true, using: :btree

  create_table "data_migrations", force: :cascade do |t|
    t.string "version", limit: 255
  end

  create_table "debug_records", force: :cascade do |t|
    t.integer  "user_id",        limit: 4
    t.string   "request_method", limit: 255
    t.text     "request_params", limit: 65535
    t.string   "request_path",   limit: 255
    t.datetime "created_at",                   null: false
    t.datetime "updated_at",                   null: false
  end

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer  "priority",   limit: 4,          default: 0
    t.integer  "attempts",   limit: 4,          default: 0
    t.text     "handler",    limit: 4294967295
    t.text     "last_error", limit: 4294967295
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by",  limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "queue",      limit: 255
  end

  add_index "delayed_jobs", ["priority", "run_at", "locked_by"], name: "index_delayed_jobs_on_priority_and_run_at_and_locked_by", using: :btree

  create_table "deliveries", force: :cascade do |t|
    t.integer  "ship_from_id", limit: 4
    t.integer  "ship_to_id",   limit: 4
    t.integer  "carrier_id",   limit: 4
    t.string   "reference",    limit: 255
    t.string   "mode",         limit: 255
    t.integer  "customer_id",  limit: 4
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
  end

  create_table "delivery_lines", force: :cascade do |t|
    t.integer  "line_number", limit: 4
    t.datetime "created_at",                                     null: false
    t.datetime "updated_at",                                     null: false
    t.integer  "delivery_id", limit: 4
    t.integer  "product_id",  limit: 4
    t.decimal  "quantity",              precision: 13, scale: 4
  end

  add_index "delivery_lines", ["delivery_id"], name: "index_delivery_lines_on_delivery_id", using: :btree

  create_table "divisions", force: :cascade do |t|
    t.string   "name",       limit: 255
    t.integer  "company_id", limit: 4
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  create_table "document_request_queue_items", force: :cascade do |t|
    t.string   "system",     limit: 255
    t.string   "identifier", limit: 255
    t.datetime "request_at"
    t.string   "locked_by",  limit: 255
    t.datetime "locked_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "document_request_queue_items", ["system", "identifier"], name: "index_document_request_queue_items_on_system_and_identifier", unique: true, using: :btree
  add_index "document_request_queue_items", ["updated_at"], name: "index_document_request_queue_items_on_updated_at", using: :btree

  create_table "drawback_allocations", force: :cascade do |t|
    t.integer  "duty_calc_export_file_line_id", limit: 4
    t.integer  "drawback_import_line_id",       limit: 4
    t.decimal  "quantity",                                precision: 13, scale: 4
    t.datetime "created_at",                                                       null: false
    t.datetime "updated_at",                                                       null: false
  end

  add_index "drawback_allocations", ["drawback_import_line_id"], name: "index_drawback_allocations_on_drawback_import_line_id", using: :btree
  add_index "drawback_allocations", ["duty_calc_export_file_line_id"], name: "index_drawback_allocations_on_duty_calc_export_file_line_id", using: :btree

  create_table "drawback_claim_audits", force: :cascade do |t|
    t.string   "export_part_number",  limit: 255
    t.string   "export_ref_1",        limit: 255
    t.date     "export_date"
    t.string   "import_part_number",  limit: 255
    t.string   "import_ref_1",        limit: 255
    t.date     "import_date"
    t.string   "import_entry_number", limit: 255
    t.decimal  "quantity",                        precision: 13, scale: 4
    t.integer  "drawback_claim_id",   limit: 4
    t.datetime "created_at",                                               null: false
    t.datetime "updated_at",                                               null: false
  end

  add_index "drawback_claim_audits", ["drawback_claim_id"], name: "index_drawback_claim_audits_on_drawback_claim_id", using: :btree
  add_index "drawback_claim_audits", ["export_part_number", "export_ref_1", "export_date"], name: "export_idx", using: :btree
  add_index "drawback_claim_audits", ["import_part_number", "import_entry_number", "import_ref_1"], name: "import_idx", using: :btree

  create_table "drawback_claims", force: :cascade do |t|
    t.integer  "importer_id",                 limit: 4
    t.string   "name",                        limit: 255
    t.date     "exports_start_date"
    t.date     "exports_end_date"
    t.string   "entry_number",                limit: 255
    t.decimal  "total_export_value",                      precision: 11, scale: 2
    t.integer  "total_pieces_exported",       limit: 4
    t.integer  "total_pieces_claimed",        limit: 4
    t.decimal  "planned_claim_amount",                    precision: 11, scale: 2
    t.decimal  "total_duty",                              precision: 11, scale: 2
    t.decimal  "duty_claimed",                            precision: 11, scale: 2
    t.decimal  "hmf_claimed",                             precision: 11, scale: 2
    t.decimal  "mpf_claimed",                             precision: 11, scale: 2
    t.decimal  "total_claim_amount",                      precision: 11, scale: 2
    t.date     "abi_accepted_date"
    t.date     "sent_to_customs_date"
    t.date     "billed_date"
    t.date     "duty_check_received_date"
    t.decimal  "duty_check_amount",                       precision: 11, scale: 2
    t.datetime "created_at",                                                       null: false
    t.datetime "updated_at",                                                       null: false
    t.decimal  "bill_amount",                             precision: 11, scale: 2
    t.decimal  "net_claim_amount",                        precision: 11, scale: 2
    t.string   "hmf_mpf_check_number",        limit: 255
    t.decimal  "hmf_mpf_check_amount",                    precision: 9,  scale: 2
    t.date     "hmf_mpf_check_received_date"
    t.date     "sent_to_client_date"
    t.date     "liquidated_date"
  end

  add_index "drawback_claims", ["importer_id"], name: "index_drawback_claims_on_importer_id", using: :btree

  create_table "drawback_export_histories", force: :cascade do |t|
    t.string   "part_number",           limit: 255
    t.string   "export_ref_1",          limit: 255
    t.date     "export_date"
    t.decimal  "quantity",                          precision: 13, scale: 4
    t.decimal  "claim_amount_per_unit",             precision: 13, scale: 4
    t.decimal  "claim_amount",                      precision: 13, scale: 4
    t.integer  "drawback_claim_id",     limit: 4
    t.datetime "created_at",                                                 null: false
    t.datetime "updated_at",                                                 null: false
  end

  add_index "drawback_export_histories", ["drawback_claim_id"], name: "index_drawback_export_histories_on_drawback_claim_id", using: :btree
  add_index "drawback_export_histories", ["part_number", "export_ref_1", "export_date"], name: "export_idx", using: :btree

  create_table "drawback_import_lines", force: :cascade do |t|
    t.decimal  "quantity",                           precision: 13, scale: 4
    t.integer  "product_id",             limit: 4
    t.integer  "line_number",            limit: 4
    t.datetime "created_at",                                                  null: false
    t.datetime "updated_at",                                                  null: false
    t.string   "entry_number",           limit: 255
    t.date     "import_date"
    t.date     "received_date"
    t.string   "port_code",              limit: 255
    t.decimal  "box_37_duty",                        precision: 10, scale: 2
    t.decimal  "box_40_duty",                        precision: 10, scale: 2
    t.decimal  "total_mpf",                          precision: 10, scale: 2
    t.string   "country_of_origin_code", limit: 255
    t.string   "part_number",            limit: 255
    t.string   "hts_code",               limit: 255
    t.string   "description",            limit: 255
    t.string   "unit_of_measure",        limit: 255
    t.decimal  "unit_price",                         precision: 16, scale: 7
    t.decimal  "rate",                               precision: 12, scale: 8
    t.decimal  "duty_per_unit",                      precision: 16, scale: 9
    t.string   "compute_code",           limit: 255
    t.boolean  "ocean"
    t.decimal  "total_invoice_value",                precision: 10, scale: 2
    t.integer  "importer_id",            limit: 4
    t.date     "liquidation_date"
    t.string   "ref_1",                  limit: 255
    t.string   "ref_2",                  limit: 255
    t.string   "country_of_export_code", limit: 255
    t.string   "color_description",      limit: 255
    t.string   "size_description",       limit: 255
    t.decimal  "exchange_rate",                      precision: 8,  scale: 6
    t.decimal  "receipt_quantity",                   precision: 8,  scale: 6
    t.decimal  "hts_duty",                           precision: 12, scale: 2
    t.decimal  "hts_quantity",                       precision: 12, scale: 2
    t.decimal  "quantity_2",                         precision: 12, scale: 2
    t.integer  "entered_value_7501",     limit: 4
    t.decimal  "total_taxes",                        precision: 12, scale: 2
    t.string   "spi_primary",            limit: 255
    t.integer  "summary_line_count",     limit: 4
    t.string   "style",                  limit: 255
    t.boolean  "single_line"
  end

  add_index "drawback_import_lines", ["importer_id"], name: "index_drawback_import_lines_on_importer_id", using: :btree
  add_index "drawback_import_lines", ["part_number"], name: "index_drawback_import_lines_on_part_number", using: :btree
  add_index "drawback_import_lines", ["product_id"], name: "index_drawback_import_lines_on_product_id", using: :btree

  create_table "drawback_upload_files", force: :cascade do |t|
    t.string   "processor",     limit: 255
    t.datetime "start_at"
    t.datetime "finish_at"
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.string   "error_message", limit: 255
  end

  add_index "drawback_upload_files", ["processor"], name: "index_drawback_upload_files_on_processor", using: :btree

  create_table "duty_calc_export_file_lines", force: :cascade do |t|
    t.date     "export_date"
    t.date     "ship_date"
    t.string   "part_number",              limit: 255
    t.string   "carrier",                  limit: 255
    t.string   "ref_1",                    limit: 255
    t.string   "ref_2",                    limit: 255
    t.string   "ref_3",                    limit: 255
    t.string   "ref_4",                    limit: 255
    t.string   "destination_country",      limit: 255
    t.decimal  "quantity",                             precision: 10
    t.string   "schedule_b_code",          limit: 255
    t.string   "hts_code",                 limit: 255
    t.string   "description",              limit: 255
    t.string   "uom",                      limit: 255
    t.string   "exporter",                 limit: 255
    t.string   "status",                   limit: 255
    t.string   "action_code",              limit: 255
    t.decimal  "nafta_duty",                           precision: 10
    t.decimal  "nafta_us_equiv_duty",                  precision: 10
    t.decimal  "nafta_duty_rate",                      precision: 10
    t.integer  "duty_calc_export_file_id", limit: 4
    t.datetime "created_at",                                          null: false
    t.datetime "updated_at",                                          null: false
    t.integer  "importer_id",              limit: 4
    t.integer  "customs_line_number",      limit: 4
    t.string   "color_description",        limit: 255
    t.string   "size_description",         limit: 255
    t.string   "style",                    limit: 255
    t.string   "ref_5",                    limit: 255
    t.string   "ref_6",                    limit: 255
  end

  add_index "duty_calc_export_file_lines", ["duty_calc_export_file_id"], name: "index_duty_calc_export_file_lines_on_duty_calc_export_file_id", using: :btree
  add_index "duty_calc_export_file_lines", ["export_date"], name: "index_duty_calc_export_file_lines_on_export_date", using: :btree
  add_index "duty_calc_export_file_lines", ["importer_id"], name: "index_duty_calc_export_file_lines_on_importer_id", using: :btree
  add_index "duty_calc_export_file_lines", ["part_number"], name: "index_duty_calc_export_file_lines_on_part_number", using: :btree
  add_index "duty_calc_export_file_lines", ["ref_1", "ref_2", "ref_3", "ref_4", "part_number", "importer_id"], name: "unique_refs", length: {"ref_1"=>100, "ref_2"=>100, "ref_3"=>100, "ref_4"=>100, "part_number"=>100, "importer_id"=>nil}, using: :btree
  add_index "duty_calc_export_file_lines", ["ref_1"], name: "index_duty_calc_export_file_lines_on_ref_1", using: :btree
  add_index "duty_calc_export_file_lines", ["ref_2"], name: "index_duty_calc_export_file_lines_on_ref_2", using: :btree

  create_table "duty_calc_export_files", force: :cascade do |t|
    t.integer  "user_id",     limit: 4
    t.datetime "created_at",            null: false
    t.datetime "updated_at",            null: false
    t.integer  "importer_id", limit: 4
  end

  add_index "duty_calc_export_files", ["importer_id"], name: "index_duty_calc_export_files_on_importer_id", using: :btree

  create_table "duty_calc_import_file_lines", force: :cascade do |t|
    t.integer  "drawback_import_line_id",  limit: 4
    t.datetime "created_at",                         null: false
    t.datetime "updated_at",                         null: false
    t.integer  "duty_calc_import_file_id", limit: 4
  end

  add_index "duty_calc_import_file_lines", ["drawback_import_line_id"], name: "index_duty_calc_import_file_lines_on_drawback_import_line_id", using: :btree
  add_index "duty_calc_import_file_lines", ["duty_calc_import_file_id"], name: "index_duty_calc_import_file_lines_on_duty_calc_import_file_id", using: :btree

  create_table "duty_calc_import_files", force: :cascade do |t|
    t.integer  "user_id",     limit: 4
    t.datetime "created_at",            null: false
    t.datetime "updated_at",            null: false
    t.integer  "importer_id", limit: 4
  end

  add_index "duty_calc_import_files", ["importer_id"], name: "index_duty_calc_import_files_on_importer_id", using: :btree

  create_table "email_attachments", force: :cascade do |t|
    t.string   "email",         limit: 1024
    t.integer  "attachment_id", limit: 4
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
  end

  create_table "entity_comparator_logs", force: :cascade do |t|
    t.integer  "recordable_id",   limit: 4
    t.string   "recordable_type", limit: 255
    t.string   "old_bucket",      limit: 255
    t.string   "old_path",        limit: 255
    t.string   "old_version",     limit: 255
    t.string   "new_bucket",      limit: 255
    t.string   "new_path",        limit: 255
    t.string   "new_version",     limit: 255
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
  end

  add_index "entity_comparator_logs", ["recordable_id", "recordable_type"], name: "index_entity_comparator_logs_rec_id_and_rec_type", using: :btree

  create_table "entity_snapshot_failures", force: :cascade do |t|
    t.integer  "snapshot_id",   limit: 4
    t.string   "snapshot_type", limit: 255
    t.text     "snapshot_json", limit: 4294967295
    t.datetime "created_at",                       null: false
    t.datetime "updated_at",                       null: false
  end

  create_table "entity_snapshots", force: :cascade do |t|
    t.string   "recordable_type",     limit: 255
    t.integer  "recordable_id",       limit: 4
    t.text     "snapshot",            limit: 65535
    t.integer  "user_id",             limit: 4
    t.datetime "created_at",                        null: false
    t.datetime "updated_at",                        null: false
    t.integer  "imported_file_id",    limit: 4
    t.integer  "change_record_id",    limit: 4
    t.integer  "bulk_process_log_id", limit: 4
    t.string   "bucket",              limit: 255
    t.string   "doc_path",            limit: 255
    t.string   "version",             limit: 255
    t.datetime "compared_at"
    t.string   "context",             limit: 255
  end

  add_index "entity_snapshots", ["bucket", "doc_path", "compared_at"], name: "Uncompared Items", using: :btree
  add_index "entity_snapshots", ["bulk_process_log_id"], name: "index_entity_snapshots_on_bulk_process_log_id", using: :btree
  add_index "entity_snapshots", ["change_record_id"], name: "index_entity_snapshots_on_change_record_id", using: :btree
  add_index "entity_snapshots", ["imported_file_id"], name: "index_entity_snapshots_on_imported_file_id", using: :btree
  add_index "entity_snapshots", ["recordable_id", "recordable_type"], name: "index_entity_snapshots_on_recordable_id_and_recordable_type", using: :btree
  add_index "entity_snapshots", ["user_id"], name: "index_entity_snapshots_on_user_id", using: :btree

  create_table "entity_type_fields", force: :cascade do |t|
    t.string   "model_field_uid", limit: 255
    t.integer  "entity_type_id",  limit: 4
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
  end

  add_index "entity_type_fields", ["entity_type_id"], name: "index_entity_type_fields_on_entity_type_id", using: :btree

  create_table "entity_types", force: :cascade do |t|
    t.string   "name",        limit: 255
    t.string   "module_type", limit: 255
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
  end

  create_table "entries", force: :cascade do |t|
    t.string   "broker_reference",                                limit: 255
    t.string   "entry_number",                                    limit: 255
    t.datetime "last_exported_from_source"
    t.string   "company_number",                                  limit: 255
    t.string   "division_number",                                 limit: 255
    t.string   "customer_number",                                 limit: 255
    t.string   "customer_name",                                   limit: 255
    t.string   "entry_type",                                      limit: 255
    t.datetime "arrival_date"
    t.datetime "entry_filed_date"
    t.datetime "release_date"
    t.datetime "first_release_date"
    t.datetime "free_date"
    t.datetime "last_billed_date"
    t.datetime "invoice_paid_date"
    t.datetime "liquidation_date"
    t.datetime "created_at",                                                                             null: false
    t.datetime "updated_at",                                                                             null: false
    t.text     "master_bills_of_lading",                          limit: 65535
    t.text     "house_bills_of_lading",                           limit: 65535
    t.text     "sub_house_bills_of_lading",                       limit: 65535
    t.text     "it_numbers",                                      limit: 65535
    t.integer  "time_to_process",                                 limit: 4
    t.string   "carrier_code",                                    limit: 255
    t.date     "duty_due_date"
    t.integer  "total_packages",                                  limit: 4
    t.decimal  "total_fees",                                                    precision: 12, scale: 2
    t.decimal  "total_duty",                                                    precision: 12, scale: 2
    t.decimal  "total_duty_direct",                                             precision: 12, scale: 2
    t.decimal  "total_entry_fee",                                               precision: 11, scale: 2
    t.decimal  "entered_value",                                                 precision: 13, scale: 2
    t.text     "customer_references",                             limit: 65535
    t.text     "po_numbers",                                      limit: 65535
    t.text     "mfids",                                           limit: 65535
    t.decimal  "total_invoiced_value",                                          precision: 13, scale: 2
    t.string   "export_country_codes",                            limit: 255
    t.string   "origin_country_codes",                            limit: 255
    t.text     "vendor_names",                                    limit: 65535
    t.string   "special_program_indicators",                      limit: 255
    t.date     "export_date"
    t.string   "merchandise_description",                         limit: 255
    t.string   "transport_mode_code",                             limit: 255
    t.decimal  "total_units",                                                   precision: 12, scale: 3
    t.string   "total_units_uoms",                                limit: 255
    t.string   "entry_port_code",                                 limit: 255
    t.string   "ult_consignee_code",                              limit: 255
    t.string   "ult_consignee_name",                              limit: 255
    t.integer  "gross_weight",                                    limit: 4
    t.string   "total_packages_uom",                              limit: 255
    t.decimal  "cotton_fee",                                                    precision: 11, scale: 2
    t.decimal  "hmf",                                                           precision: 11, scale: 2
    t.decimal  "mpf",                                                           precision: 11, scale: 2
    t.text     "container_numbers",                               limit: 65535
    t.string   "container_sizes",                                 limit: 255
    t.string   "fcl_lcl",                                         limit: 255
    t.string   "lading_port_code",                                limit: 255
    t.string   "consignee_address_1",                             limit: 255
    t.string   "consignee_address_2",                             limit: 255
    t.string   "consignee_city",                                  limit: 255
    t.string   "consignee_state",                                 limit: 255
    t.string   "unlading_port_code",                              limit: 255
    t.integer  "importer_id",                                     limit: 4
    t.string   "source_system",                                   limit: 255
    t.string   "vessel",                                          limit: 255
    t.string   "voyage",                                          limit: 255
    t.datetime "file_logged_date"
    t.integer  "import_country_id",                               limit: 4
    t.string   "importer_tax_id",                                 limit: 255
    t.string   "cargo_control_number",                            limit: 255
    t.string   "ship_terms",                                      limit: 255
    t.date     "direct_shipment_date"
    t.datetime "across_sent_date"
    t.datetime "pars_ack_date"
    t.datetime "pars_reject_date"
    t.datetime "cadex_accept_date"
    t.datetime "cadex_sent_date"
    t.string   "employee_name",                                   limit: 255
    t.string   "release_type",                                    limit: 255
    t.string   "us_exit_port_code",                               limit: 255
    t.string   "origin_state_codes",                              limit: 255
    t.string   "export_state_codes",                              limit: 255
    t.string   "recon_flags",                                     limit: 255
    t.decimal  "broker_invoice_total",                                          precision: 12, scale: 2
    t.datetime "fda_release_date"
    t.datetime "fda_review_date"
    t.datetime "fda_transmit_date"
    t.string   "release_cert_message",                            limit: 255
    t.string   "fda_message",                                     limit: 255
    t.string   "charge_codes",                                    limit: 255
    t.string   "last_file_bucket",                                limit: 255
    t.string   "last_file_path",                                  limit: 255
    t.datetime "isf_sent_date"
    t.datetime "isf_accepted_date"
    t.date     "docs_received_date"
    t.datetime "trucker_called_date"
    t.date     "edi_received_date"
    t.decimal  "total_gst",                                                     precision: 11, scale: 2
    t.decimal  "total_duty_gst",                                                precision: 11, scale: 2
    t.datetime "first_entry_sent_date"
    t.boolean  "paperless_release"
    t.boolean  "error_free_release"
    t.boolean  "census_warning"
    t.boolean  "paperless_certification"
    t.string   "destination_state",                               limit: 255
    t.string   "liquidation_type_code",                           limit: 255
    t.string   "liquidation_type",                                limit: 255
    t.string   "liquidation_action_code",                         limit: 255
    t.string   "liquidation_action_description",                  limit: 255
    t.string   "liquidation_extension_code",                      limit: 255
    t.string   "liquidation_extension_description",               limit: 255
    t.integer  "liquidation_extension_count",                     limit: 4
    t.decimal  "liquidation_duty",                                              precision: 12, scale: 2
    t.decimal  "liquidation_fees",                                              precision: 12, scale: 2
    t.decimal  "liquidation_tax",                                               precision: 12, scale: 2
    t.decimal  "liquidation_ada",                                               precision: 12, scale: 2
    t.decimal  "liquidation_cvd",                                               precision: 12, scale: 2
    t.decimal  "liquidation_total",                                             precision: 12, scale: 2
    t.string   "daily_statement_number",                          limit: 255
    t.date     "daily_statement_due_date"
    t.date     "daily_statement_approved_date"
    t.string   "monthly_statement_number",                        limit: 255
    t.date     "monthly_statement_due_date"
    t.date     "monthly_statement_received_date"
    t.date     "monthly_statement_paid_date"
    t.integer  "pay_type",                                        limit: 4
    t.datetime "first_7501_print"
    t.datetime "last_7501_print"
    t.date     "first_it_date"
    t.datetime "first_do_issued_date"
    t.text     "part_numbers",                                    limit: 65535
    t.text     "commercial_invoice_numbers",                      limit: 65535
    t.date     "eta_date"
    t.datetime "delivery_order_pickup_date"
    t.datetime "freight_pickup_date"
    t.date     "k84_receive_date"
    t.integer  "k84_month",                                       limit: 4
    t.integer  "tracking_status",                                 limit: 4
    t.date     "k84_due_date"
    t.string   "carrier_name",                                    limit: 255
    t.datetime "exam_ordered_date"
    t.date     "final_statement_date"
    t.string   "bond_type",                                       limit: 255
    t.string   "location_of_goods",                               limit: 255
    t.datetime "available_date"
    t.datetime "worksheet_date"
    t.text     "departments",                                     limit: 65535
    t.decimal  "total_add",                                                     precision: 13, scale: 4
    t.decimal  "total_cvd",                                                     precision: 13, scale: 4
    t.datetime "b3_print_date"
    t.text     "store_names",                                     limit: 65535
    t.datetime "final_delivery_date"
    t.datetime "expected_update_time"
    t.integer  "fda_pending_release_line_count",                  limit: 4
    t.string   "house_carrier_code",                              limit: 255
    t.string   "location_of_goods_description",                   limit: 255
    t.datetime "bol_received_date"
    t.datetime "cancelled_date"
    t.datetime "arrival_notice_receipt_date"
    t.decimal  "total_non_dutiable_amount",                                     precision: 13, scale: 2
    t.string   "product_lines",                                   limit: 255
    t.date     "fiscal_date"
    t.integer  "fiscal_month",                                    limit: 4
    t.integer  "fiscal_year",                                     limit: 4
    t.decimal  "other_fees",                                                    precision: 11, scale: 2
    t.boolean  "summary_rejected"
    t.datetime "documentation_request_date"
    t.datetime "po_request_date"
    t.datetime "tariff_request_date"
    t.datetime "ogd_request_date"
    t.datetime "value_currency_request_date"
    t.datetime "part_number_request_date"
    t.datetime "importer_request_date"
    t.datetime "manifest_info_received_date"
    t.datetime "one_usg_date"
    t.datetime "ams_hold_date"
    t.datetime "ams_hold_release_date"
    t.datetime "aphis_hold_date"
    t.datetime "aphis_hold_release_date"
    t.datetime "atf_hold_date"
    t.datetime "atf_hold_release_date"
    t.datetime "cargo_manifest_hold_date"
    t.datetime "cargo_manifest_hold_release_date"
    t.datetime "cbp_hold_date"
    t.datetime "cbp_hold_release_date"
    t.datetime "cbp_intensive_hold_date"
    t.datetime "cbp_intensive_hold_release_date"
    t.datetime "ddtc_hold_date"
    t.datetime "ddtc_hold_release_date"
    t.datetime "fda_hold_date"
    t.datetime "fda_hold_release_date"
    t.datetime "fsis_hold_date"
    t.datetime "fsis_hold_release_date"
    t.datetime "nhtsa_hold_date"
    t.datetime "nhtsa_hold_release_date"
    t.datetime "nmfs_hold_date"
    t.datetime "nmfs_hold_release_date"
    t.datetime "usda_hold_date"
    t.datetime "usda_hold_release_date"
    t.datetime "other_agency_hold_date"
    t.datetime "other_agency_hold_release_date"
    t.boolean  "on_hold"
    t.datetime "hold_date"
    t.datetime "hold_release_date"
    t.datetime "exam_release_date"
    t.date     "import_date"
    t.boolean  "split_shipment"
    t.string   "split_release_option",                            limit: 255
    t.datetime "fish_and_wildlife_transmitted_date"
    t.datetime "fish_and_wildlife_secure_facility_date"
    t.datetime "fish_and_wildlife_hold_date"
    t.datetime "fish_and_wildlife_hold_release_date"
    t.datetime "first_release_received_date"
    t.decimal  "total_taxes",                                                   precision: 12, scale: 2
    t.datetime "split_shipment_date"
    t.datetime "across_declaration_accepted"
    t.integer  "summary_line_count",                              limit: 4
    t.boolean  "special_tariff"
    t.date     "k84_payment_due_date"
    t.date     "miscellaneous_entry_exception_date"
    t.date     "invoice_missing_date"
    t.date     "bol_discrepancy_date"
    t.date     "detained_at_port_of_discharge_date"
    t.date     "invoice_discrepancy_date"
    t.date     "docs_missing_date"
    t.date     "hts_missing_date"
    t.date     "hts_expired_date"
    t.date     "hts_misclassified_date"
    t.date     "hts_need_additional_info_date"
    t.date     "mid_discrepancy_date"
    t.date     "additional_duty_confirmation_date"
    t.date     "pga_docs_missing_date"
    t.date     "pga_docs_incomplete_date"
    t.string   "consignee_postal_code",                           limit: 255
    t.string   "consignee_country_code",                          limit: 255
    t.datetime "summary_accepted_date"
    t.string   "bond_surety_number",                              limit: 255
    t.text     "trucker_names",                                   limit: 65535
    t.text     "deliver_to_names",                                limit: 65535
    t.datetime "customs_detention_exception_opened_date"
    t.datetime "customs_detention_exception_resolved_date"
    t.datetime "classification_inquiry_exception_opened_date"
    t.datetime "classification_inquiry_exception_resolved_date"
    t.datetime "customer_requested_hold_exception_opened_date"
    t.datetime "customer_requested_hold_exception_resolved_date"
    t.datetime "customs_exam_exception_opened_date"
    t.datetime "customs_exam_exception_resolved_date"
    t.datetime "document_discrepancy_exception_opened_date"
    t.datetime "document_discrepancy_exception_resolved_date"
    t.datetime "fda_issue_exception_opened_date"
    t.datetime "fda_issue_exception_resolved_date"
    t.datetime "fish_and_wildlife_exception_opened_date"
    t.datetime "fish_and_wildlife_exception_resolved_date"
    t.datetime "lacey_act_exception_opened_date"
    t.datetime "lacey_act_exception_resolved_date"
    t.datetime "late_documents_exception_opened_date"
    t.datetime "late_documents_exception_resolved_date"
    t.datetime "manifest_hold_exception_opened_date"
    t.datetime "manifest_hold_exception_resolved_date"
    t.datetime "missing_document_exception_opened_date"
    t.datetime "missing_document_exception_resolved_date"
    t.datetime "pending_customs_review_exception_opened_date"
    t.datetime "pending_customs_review_exception_resolved_date"
    t.datetime "price_inquiry_exception_opened_date"
    t.datetime "price_inquiry_exception_resolved_date"
    t.datetime "usda_hold_exception_opened_date"
    t.datetime "usda_hold_exception_resolved_date"
    t.datetime "reliquidation_date"
    t.integer  "broker_id",                                       limit: 4
    t.decimal  "total_freight",                                                 precision: 12, scale: 2
  end

  add_index "entries", ["arrival_date"], name: "index_entries_on_arrival_date", using: :btree
  add_index "entries", ["broker_id"], name: "index_entries_on_broker_id", using: :btree
  add_index "entries", ["broker_reference"], name: "index_entries_on_broker_reference", using: :btree
  add_index "entries", ["cargo_control_number"], name: "index_entries_on_cargo_control_number", using: :btree
  add_index "entries", ["customer_number"], name: "index_entries_on_customer_number", using: :btree
  add_index "entries", ["customer_references"], name: "index_entries_on_customer_references", length: {"customer_references"=>10}, using: :btree
  add_index "entries", ["division_number"], name: "index_entries_on_division_number", using: :btree
  add_index "entries", ["entry_number"], name: "index_entries_on_entry_number", using: :btree
  add_index "entries", ["entry_port_code"], name: "index_entries_on_entry_port_code", using: :btree
  add_index "entries", ["export_date"], name: "index_entries_on_export_date", using: :btree
  add_index "entries", ["house_bills_of_lading"], name: "index_entries_on_house_bills_of_lading", length: {"house_bills_of_lading"=>64}, using: :btree
  add_index "entries", ["import_country_id"], name: "index_entries_on_import_country_id", using: :btree
  add_index "entries", ["importer_id"], name: "index_entries_on_importer_id", using: :btree
  add_index "entries", ["k84_due_date"], name: "index_entries_on_k84_due_date", using: :btree
  add_index "entries", ["po_numbers"], name: "index_entries_on_po_numbers", length: {"po_numbers"=>10}, using: :btree
  add_index "entries", ["release_date"], name: "index_entries_on_release_date", using: :btree
  add_index "entries", ["tracking_status"], name: "index_entries_on_tracking_status", using: :btree
  add_index "entries", ["transport_mode_code"], name: "index_entries_on_transport_mode_code", using: :btree
  add_index "entries", ["updated_at"], name: "index_entries_on_updated_at", using: :btree

  create_table "entry_comments", force: :cascade do |t|
    t.integer  "entry_id",       limit: 4
    t.text     "body",           limit: 65535
    t.datetime "generated_at"
    t.string   "username",       limit: 255
    t.datetime "created_at",                   null: false
    t.datetime "updated_at",                   null: false
    t.boolean  "public_comment"
  end

  add_index "entry_comments", ["entry_id"], name: "index_entry_comments_on_entry_id", using: :btree

  create_table "entry_exceptions", force: :cascade do |t|
    t.integer  "entry_id",                limit: 4,     null: false
    t.string   "code",                    limit: 255,   null: false
    t.text     "comments",                limit: 65535
    t.datetime "resolved_date"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "exception_creation_date"
  end

  add_index "entry_exceptions", ["entry_id"], name: "index_entry_exceptions_on_entry_id", using: :btree

  create_table "entry_pga_summaries", force: :cascade do |t|
    t.integer  "entry_id",                   limit: 4,   null: false
    t.string   "agency_code",                limit: 255, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "total_pga_lines",            limit: 4
    t.integer  "total_claimed_pga_lines",    limit: 4
    t.integer  "total_disclaimed_pga_lines", limit: 4
  end

  add_index "entry_pga_summaries", ["entry_id"], name: "index_entry_pga_summaries_on_entry_id", using: :btree

  create_table "entry_purges", force: :cascade do |t|
    t.string   "broker_reference", limit: 255
    t.string   "country_iso",      limit: 255
    t.string   "source_system",    limit: 255
    t.datetime "date_purged"
    t.datetime "created_at",                   null: false
    t.datetime "updated_at",                   null: false
  end

  create_table "error_log_entries", force: :cascade do |t|
    t.string   "exception_class",          limit: 255
    t.text     "error_message",            limit: 65535
    t.text     "additional_messages_json", limit: 65535
    t.text     "backtrace_json",           limit: 65535
    t.datetime "created_at",                             null: false
    t.datetime "updated_at",                             null: false
  end

  add_index "error_log_entries", ["created_at"], name: "index_error_log_entries_on_created_at", using: :btree

  create_table "event_subscriptions", force: :cascade do |t|
    t.integer  "user_id",        limit: 4
    t.string   "event_type",     limit: 255
    t.boolean  "email"
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
    t.boolean  "system_message"
  end

  add_index "event_subscriptions", ["user_id"], name: "index_event_subscriptions_on_user_id", using: :btree

  create_table "export_job_links", force: :cascade do |t|
    t.integer "export_job_id",   limit: 4,   null: false
    t.integer "exportable_id",   limit: 4,   null: false
    t.string  "exportable_type", limit: 255, null: false
  end

  add_index "export_job_links", ["export_job_id"], name: "index_export_job_links_on_export_job_id", using: :btree
  add_index "export_job_links", ["exportable_id", "exportable_type"], name: "index_export_job_links_on_exportable_id_and_exportable_type", using: :btree

  create_table "export_jobs", force: :cascade do |t|
    t.datetime "start_time"
    t.datetime "end_time"
    t.boolean  "successful"
    t.string   "export_type", limit: 255
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
  end

  create_table "field_labels", force: :cascade do |t|
    t.string   "model_field_uid", limit: 255
    t.string   "label",           limit: 255
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
  end

  add_index "field_labels", ["model_field_uid"], name: "index_field_labels_on_model_field_uid", using: :btree

  create_table "field_validator_rules", force: :cascade do |t|
    t.string   "model_field_uid",        limit: 255
    t.string   "module_type",            limit: 255
    t.decimal  "greater_than",                         precision: 13, scale: 4
    t.decimal  "less_than",                            precision: 13, scale: 4
    t.integer  "more_than_ago",          limit: 4
    t.integer  "less_than_from_now",     limit: 4
    t.string   "more_than_ago_uom",      limit: 255
    t.string   "less_than_from_now_uom", limit: 255
    t.date     "greater_than_date"
    t.date     "less_than_date"
    t.string   "regex",                  limit: 255
    t.text     "comment",                limit: 65535
    t.string   "custom_message",         limit: 255
    t.boolean  "required"
    t.string   "starts_with",            limit: 255
    t.string   "ends_with",              limit: 255
    t.string   "contains",               limit: 255
    t.text     "one_of",                 limit: 65535
    t.integer  "minimum_length",         limit: 4
    t.integer  "maximum_length",         limit: 4
    t.datetime "created_at",                                                    null: false
    t.datetime "updated_at",                                                    null: false
    t.integer  "custom_definition_id",   limit: 4
    t.boolean  "read_only"
    t.boolean  "disabled"
    t.text     "can_edit_groups",        limit: 65535
    t.text     "can_view_groups",        limit: 65535
    t.string   "xml_tag_name",           limit: 255
    t.boolean  "mass_edit"
    t.text     "can_mass_edit_groups",   limit: 65535
    t.boolean  "allow_everyone_to_view"
  end

  add_index "field_validator_rules", ["custom_definition_id", "model_field_uid"], name: "index_field_validator_rules_on_cust_def_id_and_model_field_uid", unique: true, using: :btree
  add_index "field_validator_rules", ["model_field_uid"], name: "index_field_validator_rules_on_model_field_uid", unique: true, using: :btree

  create_table "file_import_results", force: :cascade do |t|
    t.integer  "imported_file_id",     limit: 4
    t.datetime "started_at"
    t.datetime "finished_at"
    t.integer  "run_by_id",            limit: 4
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
    t.integer  "changed_object_count", limit: 4
    t.integer  "expected_rows",        limit: 4
    t.integer  "rows_processed",       limit: 4
  end

  add_index "file_import_results", ["imported_file_id", "finished_at"], name: "index_file_import_results_on_imported_file_id_and_finished_at", using: :btree

  create_table "fiscal_months", force: :cascade do |t|
    t.integer  "year",         limit: 4
    t.integer  "month_number", limit: 4
    t.date     "start_date"
    t.date     "end_date"
    t.integer  "company_id",   limit: 4
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "fiscal_months", ["start_date", "end_date"], name: "index_fiscal_months_on_start_date_and_end_date", using: :btree

  create_table "folder_groups", force: :cascade do |t|
    t.integer "folder_id", limit: 4
    t.integer "group_id",  limit: 4
  end

  add_index "folder_groups", ["folder_id"], name: "index_folder_groups_on_folder_id", using: :btree

  create_table "folders", force: :cascade do |t|
    t.string   "name",             limit: 255
    t.integer  "base_object_id",   limit: 4,   null: false
    t.string   "base_object_type", limit: 255, null: false
    t.integer  "created_by_id",    limit: 4,   null: false
    t.datetime "created_at",                   null: false
    t.datetime "updated_at",                   null: false
    t.boolean  "archived"
  end

  add_index "folders", ["base_object_id", "base_object_type"], name: "index_folders_on_base_object_id_and_base_object_type", using: :btree
  add_index "folders", ["created_by_id"], name: "index_folders_on_created_by_id", using: :btree

  create_table "ftp_sessions", force: :cascade do |t|
    t.string   "username",             limit: 255
    t.string   "server",               limit: 255
    t.string   "file_name",            limit: 255
    t.text     "log",                  limit: 65535
    t.binary   "data",                 limit: 65535
    t.datetime "created_at",                         null: false
    t.datetime "updated_at",                         null: false
    t.string   "last_server_response", limit: 255
    t.string   "protocol",             limit: 255
    t.integer  "retry_count",          limit: 4
  end

  create_table "groups", force: :cascade do |t|
    t.string   "system_code", limit: 255
    t.string   "name",        limit: 255
    t.string   "description", limit: 255
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
  end

  add_index "groups", ["system_code"], name: "index_groups_on_system_code", unique: true, using: :btree

  create_table "histories", force: :cascade do |t|
    t.integer  "order_id",              limit: 4
    t.integer  "shipment_id",           limit: 4
    t.integer  "product_id",            limit: 4
    t.integer  "company_id",            limit: 4
    t.integer  "user_id",               limit: 4
    t.integer  "order_line_id",         limit: 4
    t.datetime "walked"
    t.datetime "created_at",                        null: false
    t.datetime "updated_at",                        null: false
    t.string   "history_type",          limit: 255
    t.integer  "sales_order_id",        limit: 4
    t.integer  "sales_order_line_id",   limit: 4
    t.integer  "delivery_id",           limit: 4
    t.integer  "entry_id",              limit: 4
    t.integer  "broker_invoice_id",     limit: 4
    t.integer  "commercial_invoice_id", limit: 4
    t.integer  "security_filing_id",    limit: 4
    t.integer  "container_id",          limit: 4
  end

  add_index "histories", ["container_id"], name: "index_histories_on_container_id", using: :btree
  add_index "histories", ["security_filing_id"], name: "index_histories_on_security_filing_id", using: :btree

  create_table "history_details", force: :cascade do |t|
    t.integer  "history_id", limit: 4
    t.string   "source_key", limit: 255
    t.string   "value",      limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  create_table "hm_i2_drawback_lines", force: :cascade do |t|
    t.string   "shipment_type",            limit: 255
    t.string   "invoice_number",           limit: 255
    t.string   "invoice_line_number",      limit: 255
    t.datetime "shipment_date"
    t.string   "consignment_number",       limit: 255
    t.string   "consignment_line_number",  limit: 255
    t.string   "po_number",                limit: 255
    t.string   "po_line_number",           limit: 255
    t.string   "part_number",              limit: 255
    t.string   "part_description",         limit: 255
    t.string   "origin_country_code",      limit: 255
    t.decimal  "quantity",                             precision: 11, scale: 2
    t.string   "carrier",                  limit: 255
    t.string   "carrier_tracking_number",  limit: 255
    t.string   "customer_order_reference", limit: 255
    t.string   "country_code",             limit: 255
    t.string   "return_reference_number",  limit: 255
    t.decimal  "item_value",                           precision: 11, scale: 2
    t.boolean  "export_received"
    t.datetime "converted_date"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "hm_i2_drawback_lines", ["carrier_tracking_number"], name: "index_hm_i2_drawback_lines_on_carrier_tracking_number", using: :btree
  add_index "hm_i2_drawback_lines", ["invoice_number", "invoice_line_number", "shipment_type"], name: "index_hm_i2_drawback_lines_on_inv_num_line_num_and_type", unique: true, using: :btree
  add_index "hm_i2_drawback_lines", ["invoice_number", "po_number", "part_number"], name: "index_hm_i2_drawback_lines_on_inv_num_po_num_and_part_num", using: :btree
  add_index "hm_i2_drawback_lines", ["shipment_date"], name: "index_hm_i2_drawback_lines_on_shipment_date", using: :btree

  create_table "hm_product_xrefs", force: :cascade do |t|
    t.string   "sku",               limit: 255
    t.string   "color_description", limit: 255
    t.string   "size_description",  limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "hm_product_xrefs", ["sku"], name: "index_hm_product_xref_on_sku", unique: true, using: :btree

  create_table "hm_receipt_lines", force: :cascade do |t|
    t.string   "location_code",      limit: 255
    t.date     "delivery_date"
    t.string   "ecc_variant_code",   limit: 255
    t.string   "order_number",       limit: 255
    t.string   "production_country", limit: 255
    t.integer  "quantity",           limit: 4
    t.string   "sku",                limit: 255
    t.string   "season",             limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "converted_date"
  end

  add_index "hm_receipt_lines", ["order_number", "sku", "delivery_date"], name: "index_hm_receipt_lines_on_order_number_sku_delivery_date", unique: true, using: :btree

  create_table "hts_translations", force: :cascade do |t|
    t.integer  "company_id",            limit: 4
    t.integer  "country_id",            limit: 4
    t.string   "hts_number",            limit: 255
    t.string   "translated_hts_number", limit: 255
    t.datetime "created_at",                        null: false
    t.datetime "updated_at",                        null: false
  end

  add_index "hts_translations", ["hts_number", "country_id", "company_id"], name: "index_hts_translations_on_hts_and_country_id_and_company_id", using: :btree

  create_table "imported_file_downloads", force: :cascade do |t|
    t.integer  "imported_file_id",      limit: 4
    t.integer  "user_id",               limit: 4
    t.string   "additional_countries",  limit: 255
    t.string   "attached_file_name",    limit: 255
    t.string   "attached_content_type", limit: 255
    t.integer  "attached_file_size",    limit: 4
    t.datetime "attached_updated_at"
    t.datetime "created_at",                        null: false
    t.datetime "updated_at",                        null: false
  end

  add_index "imported_file_downloads", ["imported_file_id"], name: "index_imported_file_downloads_on_imported_file_id", using: :btree

  create_table "imported_files", force: :cascade do |t|
    t.datetime "created_at",                                          null: false
    t.datetime "updated_at",                                          null: false
    t.datetime "processed_at"
    t.integer  "search_setup_id",       limit: 4
    t.string   "attached_file_name",    limit: 255
    t.string   "attached_content_type", limit: 255
    t.integer  "attached_file_size",    limit: 4
    t.datetime "attached_updated_at"
    t.integer  "user_id",               limit: 4
    t.string   "module_type",           limit: 255
    t.string   "update_mode",           limit: 255
    t.integer  "starting_row",          limit: 4,     default: 1
    t.integer  "starting_column",       limit: 4,     default: 1
    t.text     "note",                  limit: 65535
    t.boolean  "set_blank",                           default: false
  end

  add_index "imported_files", ["user_id"], name: "index_imported_files_on_user_id", using: :btree

  create_table "inbound_file_identifiers", force: :cascade do |t|
    t.integer "inbound_file_id", limit: 4
    t.string  "identifier_type", limit: 255
    t.string  "value",           limit: 255
    t.string  "module_type",     limit: 255
    t.integer "module_id",       limit: 4
  end

  add_index "inbound_file_identifiers", ["identifier_type", "value"], name: "index_inbound_file_identifiers_on_identifier_type_and_value", using: :btree
  add_index "inbound_file_identifiers", ["inbound_file_id"], name: "index_inbound_file_identifiers_on_inbound_file_id", using: :btree
  add_index "inbound_file_identifiers", ["module_id"], name: "index_inbound_file_identifiers_on_module_id", using: :btree
  add_index "inbound_file_identifiers", ["module_type", "module_id"], name: "index_inbound_file_identifiers_on_module_type_and_module_id", using: :btree
  add_index "inbound_file_identifiers", ["value"], name: "index_inbound_file_identifiers_on_value", using: :btree

  create_table "inbound_file_messages", force: :cascade do |t|
    t.integer "inbound_file_id", limit: 4
    t.string  "message_status",  limit: 255
    t.text    "message",         limit: 65535
  end

  add_index "inbound_file_messages", ["inbound_file_id"], name: "index_inbound_file_messages_on_inbound_file_id", using: :btree

  create_table "inbound_files", force: :cascade do |t|
    t.string   "file_name",                   limit: 255
    t.string   "receipt_location",            limit: 255
    t.string   "parser_name",                 limit: 255
    t.integer  "company_id",                  limit: 4
    t.datetime "process_start_date"
    t.datetime "process_end_date"
    t.string   "process_status",              limit: 255
    t.string   "isa_number",                  limit: 255
    t.string   "s3_bucket",                   limit: 255
    t.string   "s3_path",                     limit: 255
    t.integer  "requeue_count",               limit: 4
    t.datetime "original_process_start_date"
    t.datetime "created_at",                              null: false
    t.datetime "updated_at",                              null: false
  end

  add_index "inbound_files", ["s3_bucket", "s3_path"], name: "index_inbound_files_on_s3_bucket_and_s3_path", using: :btree

  create_table "instance_informations", force: :cascade do |t|
    t.string   "host",          limit: 255
    t.datetime "last_check_in"
    t.string   "version",       limit: 255
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.string   "name",          limit: 255
    t.string   "role",          limit: 255
  end

  create_table "instant_classification_result_records", force: :cascade do |t|
    t.integer  "instant_classification_result_id", limit: 4
    t.integer  "entity_snapshot_id",               limit: 4
    t.integer  "product_id",                       limit: 4
    t.datetime "created_at",                                 null: false
    t.datetime "updated_at",                                 null: false
  end

  add_index "instant_classification_result_records", ["instant_classification_result_id"], name: "result_ids", using: :btree

  create_table "instant_classification_results", force: :cascade do |t|
    t.integer  "run_by_id",   limit: 4
    t.datetime "run_at"
    t.datetime "finished_at"
    t.datetime "created_at",            null: false
    t.datetime "updated_at",            null: false
  end

  add_index "instant_classification_results", ["run_by_id"], name: "index_instant_classification_results_on_run_by_id", using: :btree

  create_table "instant_classifications", force: :cascade do |t|
    t.string   "name",       limit: 255
    t.integer  "rank",       limit: 4
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  create_table "intacct_alliance_exports", force: :cascade do |t|
    t.string   "file_number",              limit: 255
    t.string   "suffix",                   limit: 255
    t.datetime "data_requested_date"
    t.datetime "data_received_date"
    t.datetime "created_at",                                                    null: false
    t.datetime "updated_at",                                                    null: false
    t.string   "division",                 limit: 255
    t.string   "customer_number",          limit: 255
    t.date     "invoice_date"
    t.string   "check_number",             limit: 255
    t.decimal  "ap_total",                             precision: 12, scale: 2
    t.decimal  "ar_total",                             precision: 12, scale: 2
    t.string   "export_type",              limit: 255
    t.string   "broker_reference",         limit: 255
    t.string   "shipment_number",          limit: 255
    t.string   "shipment_customer_number", limit: 255
  end

  add_index "intacct_alliance_exports", ["file_number", "suffix"], name: "index_intacct_alliance_exports_on_file_number_and_suffix", using: :btree

  create_table "intacct_checks", force: :cascade do |t|
    t.string   "company",                    limit: 255
    t.string   "file_number",                limit: 255
    t.string   "suffix",                     limit: 255
    t.string   "bill_number",                limit: 255
    t.string   "customer_number",            limit: 255
    t.string   "vendor_number",              limit: 255
    t.string   "check_number",               limit: 255
    t.date     "check_date"
    t.string   "bank_number",                limit: 255
    t.string   "vendor_reference",           limit: 255
    t.decimal  "amount",                                   precision: 10, scale: 2
    t.string   "freight_file",               limit: 255
    t.string   "broker_file",                limit: 255
    t.string   "location",                   limit: 255
    t.string   "line_of_business",           limit: 255
    t.string   "currency",                   limit: 255
    t.string   "gl_account",                 limit: 255
    t.string   "bank_cash_gl_account",       limit: 255
    t.integer  "intacct_alliance_export_id", limit: 4
    t.datetime "intacct_upload_date"
    t.string   "intacct_key",                limit: 255
    t.text     "intacct_errors",             limit: 65535
    t.integer  "intacct_payable_id",         limit: 4
    t.string   "intacct_adjustment_key",     limit: 255
    t.datetime "created_at",                                                        null: false
    t.datetime "updated_at",                                                        null: false
    t.boolean  "voided"
  end

  add_index "intacct_checks", ["company", "bill_number", "vendor_number"], name: "index_by_payable_identifiers", using: :btree
  add_index "intacct_checks", ["file_number", "suffix", "check_number", "check_date", "bank_number"], name: "index_by_check_unique_identifers", length: {"file_number"=>10, "suffix"=>10, "check_number"=>nil, "check_date"=>nil, "bank_number"=>10}, using: :btree
  add_index "intacct_checks", ["intacct_alliance_export_id"], name: "index_intacct_checks_on_intacct_alliance_export_id", using: :btree

  create_table "intacct_payable_lines", force: :cascade do |t|
    t.integer "intacct_payable_id",   limit: 4
    t.string  "gl_account",           limit: 255
    t.decimal "amount",                           precision: 12, scale: 2
    t.string  "customer_number",      limit: 255
    t.string  "charge_code",          limit: 255
    t.string  "charge_description",   limit: 255
    t.string  "location",             limit: 255
    t.string  "line_of_business",     limit: 255
    t.string  "freight_file",         limit: 255
    t.string  "broker_file",          limit: 255
    t.string  "check_number",         limit: 255
    t.string  "bank_number",          limit: 255
    t.date    "check_date"
    t.string  "bank_cash_gl_account", limit: 255
  end

  add_index "intacct_payable_lines", ["intacct_payable_id"], name: "index_intacct_payable_lines_on_intacct_payable_id", using: :btree

  create_table "intacct_payables", force: :cascade do |t|
    t.integer  "intacct_alliance_export_id", limit: 4
    t.string   "company",                    limit: 255
    t.string   "bill_number",                limit: 255
    t.date     "bill_date"
    t.string   "vendor_number",              limit: 255
    t.string   "vendor_reference",           limit: 255
    t.string   "currency",                   limit: 255
    t.datetime "intacct_upload_date"
    t.string   "intacct_key",                limit: 255
    t.text     "intacct_errors",             limit: 65535
    t.datetime "created_at",                               null: false
    t.datetime "updated_at",                               null: false
    t.string   "payable_type",               limit: 255
    t.string   "check_number",               limit: 255
    t.string   "shipment_customer_number",   limit: 255
  end

  add_index "intacct_payables", ["company", "vendor_number", "bill_number"], name: "intacct_payables_by_company_vendor_number_bill_number", using: :btree
  add_index "intacct_payables", ["intacct_alliance_export_id"], name: "index_intacct_payables_on_intacct_alliance_export_id", using: :btree

  create_table "intacct_receivable_lines", force: :cascade do |t|
    t.integer  "intacct_receivable_id", limit: 4
    t.decimal  "amount",                            precision: 12, scale: 2
    t.string   "charge_code",           limit: 255
    t.string   "charge_description",    limit: 255
    t.string   "location",              limit: 255
    t.string   "line_of_business",      limit: 255
    t.string   "freight_file",          limit: 255
    t.string   "broker_file",           limit: 255
    t.string   "vendor_number",         limit: 255
    t.string   "vendor_reference",      limit: 255
    t.datetime "created_at",                                                 null: false
    t.datetime "updated_at",                                                 null: false
  end

  add_index "intacct_receivable_lines", ["intacct_receivable_id"], name: "index_intacct_receivable_lines_on_intacct_receivable_id", using: :btree

  create_table "intacct_receivables", force: :cascade do |t|
    t.integer  "intacct_alliance_export_id", limit: 4
    t.string   "receivable_type",            limit: 255
    t.string   "company",                    limit: 255
    t.string   "invoice_number",             limit: 255
    t.date     "invoice_date"
    t.string   "customer_number",            limit: 255
    t.string   "currency",                   limit: 255
    t.datetime "intacct_upload_date"
    t.string   "intacct_key",                limit: 255
    t.text     "intacct_errors",             limit: 65535
    t.datetime "created_at",                               null: false
    t.datetime "updated_at",                               null: false
    t.string   "customer_reference",         limit: 255
    t.string   "lmd_identifier",             limit: 255
    t.string   "shipment_customer_number",   limit: 255
  end

  add_index "intacct_receivables", ["company", "customer_number", "invoice_number"], name: "intacct_recveivables_by_company_customer_number_invoice_number", using: :btree
  add_index "intacct_receivables", ["intacct_alliance_export_id"], name: "index_intacct_receivables_on_intacct_alliance_export_id", using: :btree
  add_index "intacct_receivables", ["lmd_identifier"], name: "index_intacct_receivables_on_lmd_identifier", using: :btree

  create_table "invoice_lines", force: :cascade do |t|
    t.decimal  "air_sea_discount",                        precision: 12, scale: 2
    t.integer  "country_export_id",           limit: 4
    t.integer  "country_origin_id",           limit: 4
    t.string   "department",                  limit: 255
    t.decimal  "early_pay_discount",                      precision: 12, scale: 2
    t.boolean  "first_sale"
    t.boolean  "fish_wildlife"
    t.decimal  "gross_weight",                            precision: 12, scale: 2
    t.string   "gross_weight_uom",            limit: 255
    t.string   "hts_number",                  limit: 255
    t.integer  "invoice_id",                  limit: 4
    t.integer  "line_number",                 limit: 4
    t.string   "mid",                         limit: 255
    t.decimal  "middleman_charge",                        precision: 12, scale: 2
    t.decimal  "net_weight",                              precision: 12, scale: 2
    t.string   "net_weight_uom",              limit: 255
    t.integer  "order_id",                    limit: 4
    t.integer  "order_line_id",               limit: 4
    t.string   "part_description",            limit: 255
    t.string   "part_number",                 limit: 255
    t.decimal  "pieces",                                  precision: 13, scale: 4
    t.string   "po_number",                   limit: 255
    t.integer  "product_id",                  limit: 4
    t.decimal  "quantity",                                precision: 12, scale: 3
    t.string   "quantity_uom",                limit: 255
    t.decimal  "trade_discount",                          precision: 12, scale: 2
    t.decimal  "unit_price",                              precision: 12, scale: 3
    t.decimal  "value_domestic",                          precision: 13, scale: 2
    t.decimal  "value_foreign",                           precision: 11, scale: 2
    t.integer  "variant_id",                  limit: 4
    t.decimal  "volume",                                  precision: 11, scale: 2
    t.string   "volume_uom",                  limit: 255
    t.datetime "created_at",                                                       null: false
    t.datetime "updated_at",                                                       null: false
    t.string   "po_line_number",              limit: 255
    t.string   "master_bill_of_lading",       limit: 255
    t.string   "carrier_code",                limit: 255
    t.integer  "cartons",                     limit: 4
    t.string   "container_number",            limit: 255
    t.boolean  "related_parties"
    t.decimal  "customs_quantity",                        precision: 12, scale: 2
    t.string   "customs_quantity_uom",        limit: 255
    t.string   "spi",                         limit: 255
    t.string   "spi2",                        limit: 255
    t.string   "carrier_name",                limit: 255
    t.string   "customer_reference_number",   limit: 255
    t.string   "customer_reference_number_2", limit: 255
    t.string   "secondary_po_number",         limit: 255
    t.string   "secondary_po_line_number",    limit: 255
    t.string   "house_bill_of_lading",        limit: 255
    t.string   "sku",                         limit: 255
  end

  add_index "invoice_lines", ["invoice_id"], name: "index_invoice_lines_on_invoice_id", using: :btree
  add_index "invoice_lines", ["part_number"], name: "index_invoice_lines_on_part_number", using: :btree
  add_index "invoice_lines", ["po_number"], name: "index_invoice_lines_on_po_number", using: :btree

  create_table "invoiced_events", force: :cascade do |t|
    t.integer  "billable_event_id",      limit: 4,   null: false
    t.integer  "vfi_invoice_line_id",    limit: 4
    t.string   "invoice_generator_name", limit: 255
    t.string   "charge_type",            limit: 255
    t.datetime "created_at",                         null: false
    t.datetime "updated_at",                         null: false
  end

  add_index "invoiced_events", ["billable_event_id"], name: "index_invoiced_events_on_billable_event_id", using: :btree
  add_index "invoiced_events", ["vfi_invoice_line_id"], name: "index_invoiced_events_on_vfi_invoice_line_id", using: :btree

  create_table "invoices", force: :cascade do |t|
    t.integer  "country_origin_id",           limit: 4
    t.string   "currency",                    limit: 255
    t.string   "customer_reference_number",   limit: 255
    t.text     "description_of_goods",        limit: 65535
    t.decimal  "exchange_rate",                             precision: 8,  scale: 6
    t.integer  "factory_id",                  limit: 4
    t.decimal  "gross_weight",                              precision: 11, scale: 2
    t.string   "gross_weight_uom",            limit: 255
    t.integer  "importer_id",                 limit: 4
    t.date     "invoice_date"
    t.string   "invoice_number",              limit: 255
    t.decimal  "invoice_total_domestic",                    precision: 13, scale: 2
    t.decimal  "invoice_total_foreign",                     precision: 13, scale: 2
    t.decimal  "net_invoice_total",                         precision: 13, scale: 2
    t.decimal  "net_weight",                                precision: 11, scale: 2
    t.string   "net_weight_uom",              limit: 255
    t.string   "ship_mode",                   limit: 255
    t.integer  "ship_to_id",                  limit: 4
    t.string   "terms_of_payment",            limit: 255
    t.string   "terms_of_sale",               limit: 255
    t.decimal  "total_charges",                             precision: 11, scale: 2
    t.decimal  "total_discounts",                           precision: 12, scale: 2
    t.integer  "vendor_id",                   limit: 4
    t.decimal  "volume",                                    precision: 11, scale: 5
    t.string   "volume_uom",                  limit: 255
    t.datetime "created_at",                                                         null: false
    t.datetime "updated_at",                                                         null: false
    t.boolean  "manually_generated"
    t.datetime "last_exported_from_source"
    t.string   "last_file_bucket",            limit: 255
    t.string   "last_file_path",              limit: 255
    t.integer  "consignee_id",                limit: 4
    t.integer  "country_import_id",           limit: 4
    t.string   "customer_reference_number_2", limit: 255
  end

  add_index "invoices", ["importer_id"], name: "index_invoices_on_importer_id", using: :btree
  add_index "invoices", ["invoice_number"], name: "index_invoices_on_invoice_number", using: :btree

  create_table "item_change_subscriptions", force: :cascade do |t|
    t.integer  "user_id",               limit: 4
    t.integer  "order_id",              limit: 4
    t.integer  "shipment_id",           limit: 4
    t.integer  "product_id",            limit: 4
    t.boolean  "app_message"
    t.boolean  "email"
    t.datetime "created_at",                      null: false
    t.datetime "updated_at",                      null: false
    t.integer  "sales_order_id",        limit: 4
    t.integer  "delivery_id",           limit: 4
    t.integer  "entry_id",              limit: 4
    t.integer  "broker_invoice_id",     limit: 4
    t.integer  "commercial_invoice_id", limit: 4
    t.integer  "security_filing_id",    limit: 4
    t.integer  "container_id",          limit: 4
    t.integer  "company_id",            limit: 4
  end

  add_index "item_change_subscriptions", ["company_id"], name: "index_item_change_subscriptions_on_company_id", using: :btree
  add_index "item_change_subscriptions", ["container_id"], name: "index_item_change_subscriptions_on_container_id", using: :btree
  add_index "item_change_subscriptions", ["security_filing_id"], name: "index_item_change_subscriptions_on_security_filing_id", using: :btree

  create_table "key_json_items", force: :cascade do |t|
    t.string "key_scope",   limit: 255
    t.string "logical_key", limit: 255
    t.text   "json_data",   limit: 65535
  end

  add_index "key_json_items", ["key_scope", "logical_key"], name: "scoped_logical_keys", unique: true, using: :btree

  create_table "linkable_attachment_import_rules", force: :cascade do |t|
    t.string   "path",            limit: 255
    t.string   "model_field_uid", limit: 255
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
  end

  create_table "linkable_attachments", force: :cascade do |t|
    t.string   "model_field_uid", limit: 255
    t.string   "value",           limit: 255
    t.integer  "attachment_id",   limit: 4
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
  end

  add_index "linkable_attachments", ["attachment_id"], name: "linkable_attachment_id", using: :btree
  add_index "linkable_attachments", ["model_field_uid"], name: "linkable_mfuid", using: :btree

  create_table "linked_attachments", force: :cascade do |t|
    t.integer  "linkable_attachment_id", limit: 4
    t.string   "attachable_type",        limit: 255
    t.integer  "attachable_id",          limit: 4
    t.datetime "created_at",                         null: false
    t.datetime "updated_at",                         null: false
  end

  add_index "linked_attachments", ["attachable_id", "attachable_type"], name: "linked_type", using: :btree
  add_index "linked_attachments", ["linkable_attachment_id"], name: "linked_attch_id", using: :btree

  create_table "linked_companies", id: false, force: :cascade do |t|
    t.integer "parent_id", limit: 4
    t.integer "child_id",  limit: 4
  end

  add_index "linked_companies", ["parent_id", "child_id"], name: "index_linked_companies_on_parent_id_and_child_id", unique: true, using: :btree

  create_table "locations", force: :cascade do |t|
    t.string   "locode",       limit: 255
    t.string   "name",         limit: 255
    t.string   "sub_division", limit: 255
    t.string   "function",     limit: 255
    t.string   "status",       limit: 255
    t.string   "iata",         limit: 255
    t.string   "coordinates",  limit: 255
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
  end

  create_table "locks", force: :cascade do |t|
    t.string   "name",       limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "locks", ["name"], name: "index_locks_on_name", unique: true, using: :btree

  create_table "mailing_lists", force: :cascade do |t|
    t.string   "system_code",       limit: 255,                   null: false
    t.string   "name",              limit: 255
    t.datetime "created_at",                                      null: false
    t.datetime "updated_at",                                      null: false
    t.integer  "user_id",           limit: 4
    t.integer  "company_id",        limit: 4
    t.text     "email_addresses",   limit: 65535
    t.boolean  "non_vfi_addresses"
    t.boolean  "hidden",                          default: false
  end

  add_index "mailing_lists", ["system_code"], name: "index_mailing_lists_on_system_code", unique: true, using: :btree

  create_table "manufacturer_ids", force: :cascade do |t|
    t.string   "mid",         limit: 255
    t.string   "name",        limit: 255
    t.string   "address_1",   limit: 255
    t.string   "address_2",   limit: 255
    t.string   "city",        limit: 255
    t.string   "postal_code", limit: 255
    t.string   "country",     limit: 255
    t.boolean  "active"
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
  end

  add_index "manufacturer_ids", ["mid"], name: "index_manufacturer_ids_on_mid", using: :btree

  create_table "master_setups", force: :cascade do |t|
    t.string   "uuid",                        limit: 255
    t.datetime "created_at",                                                                null: false
    t.datetime "updated_at",                                                                null: false
    t.string   "logo_image",                  limit: 255
    t.string   "system_code",                 limit: 255
    t.boolean  "order_enabled",                             default: true,                  null: false
    t.boolean  "shipment_enabled",                          default: true,                  null: false
    t.boolean  "sales_order_enabled",                       default: true,                  null: false
    t.boolean  "delivery_enabled",                          default: true,                  null: false
    t.boolean  "classification_enabled",                    default: true,                  null: false
    t.boolean  "ftp_polling_active"
    t.text     "system_message",              limit: 65535
    t.string   "migration_host",              limit: 255
    t.string   "target_version",              limit: 255
    t.text     "custom_features",             limit: 65535
    t.boolean  "entry_enabled"
    t.boolean  "broker_invoice_enabled"
    t.string   "request_host",                limit: 255
    t.boolean  "drawback_enabled"
    t.boolean  "security_filing_enabled"
    t.datetime "last_delayed_job_error_sent",               default: '2001-01-01 00:00:00'
    t.string   "stats_api_key",               limit: 255
    t.boolean  "project_enabled"
    t.boolean  "vendor_management_enabled"
    t.boolean  "variant_enabled"
    t.boolean  "trade_lane_enabled"
    t.boolean  "vfi_invoice_enabled"
    t.string   "friendly_name",               limit: 255
    t.boolean  "customs_statements_enabled"
    t.boolean  "suppress_email"
    t.boolean  "suppress_ftp"
    t.string   "send_test_files_to_instance", limit: 255,   default: "vfi-test"
    t.boolean  "invoices_enabled"
  end

  create_table "messages", force: :cascade do |t|
    t.integer  "user_id",    limit: 4
    t.string   "subject",    limit: 255
    t.text     "body",       limit: 65535
    t.string   "folder",     limit: 255,   default: "inbox"
    t.boolean  "viewed",                   default: false
    t.string   "link_name",  limit: 255
    t.string   "link_path",  limit: 255
    t.datetime "created_at",                                 null: false
    t.datetime "updated_at",                                 null: false
  end

  add_index "messages", ["user_id", "viewed"], name: "index_messages_on_user_id_and_viewed", using: :btree
  add_index "messages", ["user_id"], name: "index_messages_on_user_id", using: :btree

  create_table "milestone_definitions", force: :cascade do |t|
    t.integer "milestone_plan_id",                limit: 4
    t.string  "model_field_uid",                  limit: 255
    t.integer "days_after_previous",              limit: 4
    t.integer "previous_milestone_definition_id", limit: 4
    t.boolean "final_milestone"
    t.integer "custom_definition_id",             limit: 4
    t.integer "display_rank",                     limit: 4
  end

  add_index "milestone_definitions", ["milestone_plan_id"], name: "index_milestone_definitions_on_milestone_plan_id", using: :btree

  create_table "milestone_forecast_sets", force: :cascade do |t|
    t.integer  "piece_set_id", limit: 4
    t.string   "state",        limit: 255
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
  end

  add_index "milestone_forecast_sets", ["piece_set_id"], name: "one_per_piece_set", unique: true, using: :btree
  add_index "milestone_forecast_sets", ["state"], name: "mfs_state", using: :btree

  create_table "milestone_forecasts", force: :cascade do |t|
    t.integer  "milestone_definition_id",   limit: 4
    t.integer  "milestone_forecast_set_id", limit: 4
    t.date     "planned"
    t.date     "forecast"
    t.string   "state",                     limit: 255
    t.datetime "created_at",                            null: false
    t.datetime "updated_at",                            null: false
  end

  add_index "milestone_forecasts", ["milestone_forecast_set_id", "milestone_definition_id"], name: "unique_forecasts", unique: true, using: :btree
  add_index "milestone_forecasts", ["state"], name: "mf_state", using: :btree

  create_table "milestone_notification_configs", force: :cascade do |t|
    t.string  "customer_number",    limit: 255
    t.text    "setup",              limit: 65535
    t.boolean "enabled"
    t.string  "output_style",       limit: 255
    t.boolean "testing"
    t.string  "module_type",        limit: 255
    t.string  "parent_system_code", limit: 255
    t.boolean "gtn_time_modifier"
  end

  add_index "milestone_notification_configs", ["module_type", "customer_number", "testing"], name: "index_milestone_configs_on_type_cust_no_testing", using: :btree
  add_index "milestone_notification_configs", ["module_type", "parent_system_code", "testing"], name: "idx_milestone_configs_on_type_parent_sys_code_testing", using: :btree

  create_table "milestone_plans", force: :cascade do |t|
    t.string   "name",       limit: 255
    t.string   "code",       limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  create_table "monthly_statements", force: :cascade do |t|
    t.string   "statement_number",            limit: 255
    t.string   "status",                      limit: 255
    t.date     "received_date"
    t.date     "final_received_date"
    t.date     "due_date"
    t.date     "paid_date"
    t.string   "port_code",                   limit: 255
    t.string   "pay_type",                    limit: 255
    t.string   "customer_number",             limit: 255
    t.integer  "importer_id",                 limit: 4
    t.decimal  "total_amount",                            precision: 11, scale: 2
    t.decimal  "preliminary_total_amount",                precision: 11, scale: 2
    t.decimal  "duty_amount",                             precision: 11, scale: 2
    t.decimal  "preliminary_duty_amount",                 precision: 11, scale: 2
    t.decimal  "tax_amount",                              precision: 11, scale: 2
    t.decimal  "preliminary_tax_amount",                  precision: 11, scale: 2
    t.decimal  "cvd_amount",                              precision: 11, scale: 2
    t.decimal  "preliminary_cvd_amount",                  precision: 11, scale: 2
    t.decimal  "add_amount",                              precision: 11, scale: 2
    t.decimal  "preliminary_add_amount",                  precision: 11, scale: 2
    t.decimal  "interest_amount",                         precision: 11, scale: 2
    t.decimal  "preliminary_interest_amount",             precision: 11, scale: 2
    t.decimal  "fee_amount",                              precision: 11, scale: 2
    t.decimal  "preliminary_fee_amount",                  precision: 11, scale: 2
    t.string   "last_file_bucket",            limit: 255
    t.string   "last_file_path",              limit: 255
    t.datetime "last_exported_from_source"
    t.datetime "created_at",                                                       null: false
    t.datetime "updated_at",                                                       null: false
  end

  add_index "monthly_statements", ["importer_id"], name: "index_monthly_statements_on_importer_id", using: :btree
  add_index "monthly_statements", ["statement_number"], name: "index_monthly_statements_on_statement_number", unique: true, using: :btree

  create_table "non_invoiced_events", force: :cascade do |t|
    t.integer  "billable_event_id",      limit: 4,   null: false
    t.string   "invoice_generator_name", limit: 255
    t.datetime "created_at",                         null: false
    t.datetime "updated_at",                         null: false
  end

  add_index "non_invoiced_events", ["billable_event_id"], name: "index_non_invoiced_events_on_billable_event_id", using: :btree

  create_table "official_quotas", force: :cascade do |t|
    t.string   "hts_code",                       limit: 255
    t.integer  "country_id",                     limit: 4
    t.decimal  "square_meter_equivalent_factor",             precision: 13, scale: 4
    t.string   "category",                       limit: 255
    t.string   "unit_of_measure",                limit: 255
    t.integer  "official_tariff_id",             limit: 4
    t.datetime "created_at",                                                          null: false
    t.datetime "updated_at",                                                          null: false
  end

  add_index "official_quotas", ["country_id", "hts_code"], name: "index_official_quotas_on_country_id_and_hts_code", using: :btree

  create_table "official_schedule_b_codes", force: :cascade do |t|
    t.string   "hts_code",               limit: 255
    t.text     "short_description",      limit: 65535
    t.text     "long_description",       limit: 65535
    t.text     "quantity_1",             limit: 65535
    t.text     "quantity_2",             limit: 65535
    t.string   "sitc_code",              limit: 255
    t.string   "end_use_classification", limit: 255
    t.string   "usda_code",              limit: 255
    t.string   "naics_classification",   limit: 255
    t.string   "hitech_classification",  limit: 255
    t.datetime "created_at",                           null: false
    t.datetime "updated_at",                           null: false
  end

  create_table "official_tariff_meta_datas", force: :cascade do |t|
    t.string   "hts_code",             limit: 255
    t.integer  "country_id",           limit: 4
    t.boolean  "auto_classify_ignore"
    t.text     "notes",                limit: 65535
    t.datetime "created_at",                         null: false
    t.datetime "updated_at",                         null: false
    t.string   "summary_description",  limit: 255
  end

  add_index "official_tariff_meta_datas", ["country_id", "hts_code"], name: "index_official_tariff_meta_datas_on_country_id_and_hts_code", using: :btree

  create_table "official_tariffs", force: :cascade do |t|
    t.integer  "country_id",                       limit: 4
    t.string   "hts_code",                         limit: 255
    t.text     "full_description",                 limit: 65535
    t.text     "special_rates",                    limit: 65535
    t.string   "general_rate",                     limit: 255
    t.datetime "created_at",                                                             null: false
    t.datetime "updated_at",                                                             null: false
    t.text     "chapter",                          limit: 65535
    t.text     "heading",                          limit: 65535
    t.text     "sub_heading",                      limit: 65535
    t.text     "remaining_description",            limit: 65535
    t.string   "add_valorem_rate",                 limit: 255
    t.string   "per_unit_rate",                    limit: 255
    t.string   "calculation_method",               limit: 255
    t.string   "most_favored_nation_rate",         limit: 255
    t.string   "general_preferential_tariff_rate", limit: 255
    t.string   "erga_omnes_rate",                  limit: 255
    t.string   "unit_of_measure",                  limit: 255
    t.text     "column_2_rate",                    limit: 65535
    t.string   "import_regulations",               limit: 255
    t.string   "export_regulations",               limit: 255
    t.string   "common_rate",                      limit: 255
    t.integer  "use_count",                        limit: 4
    t.string   "special_rate_key",                 limit: 255
    t.decimal  "common_rate_decimal",                            precision: 8, scale: 4
    t.string   "fda_indicator",                    limit: 255
  end

  add_index "official_tariffs", ["country_id", "hts_code"], name: "index_official_tariffs_on_country_id_and_hts_code", using: :btree
  add_index "official_tariffs", ["hts_code"], name: "index_official_tariffs_on_hts_code", using: :btree

  create_table "one_time_alert_log_entries", force: :cascade do |t|
    t.integer  "one_time_alert_id", limit: 4
    t.datetime "logged_at"
    t.integer  "alertable_id",      limit: 4
    t.string   "alertable_type",    limit: 255
    t.string   "reference_fields",  limit: 255
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
  end

  create_table "one_time_alerts", force: :cascade do |t|
    t.integer  "user_id",                        limit: 4
    t.integer  "expire_date_last_updated_by_id", limit: 4
    t.integer  "mailing_list_id",                limit: 4
    t.string   "name",                           limit: 255
    t.string   "module_type",                    limit: 255
    t.text     "email_addresses",                limit: 65535
    t.string   "email_subject",                  limit: 255
    t.text     "email_body",                     limit: 65535
    t.boolean  "blind_copy_me"
    t.date     "enabled_date"
    t.date     "expire_date"
    t.datetime "created_at",                                                   null: false
    t.datetime "updated_at",                                                   null: false
    t.boolean  "inactive",                                     default: false
  end

  create_table "order_lines", force: :cascade do |t|
    t.decimal  "price_per_unit",                precision: 13, scale: 4
    t.integer  "order_id",          limit: 4
    t.datetime "created_at",                                             null: false
    t.datetime "updated_at",                                             null: false
    t.integer  "line_number",       limit: 4
    t.integer  "product_id",        limit: 4
    t.decimal  "quantity",                      precision: 13, scale: 4
    t.string   "currency",          limit: 255
    t.string   "country_of_origin", limit: 255
    t.string   "hts",               limit: 255
    t.string   "sku",               limit: 255
    t.string   "unit_of_measure",   limit: 255
    t.integer  "ship_to_id",        limit: 4
    t.integer  "total_cost_digits", limit: 4
    t.integer  "variant_id",        limit: 4
    t.decimal  "unit_msrp",                     precision: 13, scale: 4
  end

  add_index "order_lines", ["order_id"], name: "index_order_lines_on_order_id", using: :btree
  add_index "order_lines", ["product_id"], name: "index_order_lines_on_product_id", using: :btree
  add_index "order_lines", ["ship_to_id"], name: "index_order_lines_on_ship_to_id", using: :btree
  add_index "order_lines", ["sku"], name: "index_order_lines_on_sku", using: :btree
  add_index "order_lines", ["variant_id"], name: "index_order_lines_on_variant_id", using: :btree

  create_table "orders", force: :cascade do |t|
    t.string   "order_number",                 limit: 255
    t.date     "order_date"
    t.integer  "division_id",                  limit: 4
    t.datetime "created_at",                                 null: false
    t.datetime "updated_at",                                 null: false
    t.integer  "vendor_id",                    limit: 4
    t.integer  "ship_to_id",                   limit: 4
    t.integer  "importer_id",                  limit: 4
    t.string   "customer_order_number",        limit: 255
    t.string   "last_file_bucket",             limit: 255
    t.string   "last_file_path",               limit: 255
    t.datetime "last_exported_from_source"
    t.string   "mode",                         limit: 255
    t.date     "ship_window_start"
    t.date     "ship_window_end"
    t.date     "first_expected_delivery_date"
    t.date     "last_revised_date"
    t.integer  "agent_id",                     limit: 4
    t.string   "approval_status",              limit: 255
    t.string   "fob_point",                    limit: 255
    t.datetime "closed_at"
    t.integer  "closed_by_id",                 limit: 4
    t.integer  "factory_id",                   limit: 4
    t.string   "terms_of_sale",                limit: 255
    t.string   "season",                       limit: 255
    t.string   "product_category",             limit: 255
    t.string   "currency",                     limit: 255
    t.string   "terms_of_payment",             limit: 255
    t.integer  "ship_from_id",                 limit: 4
    t.integer  "order_from_address_id",        limit: 4
    t.integer  "tpp_survey_response_id",       limit: 4
    t.integer  "accepted_by_id",               limit: 4
    t.datetime "accepted_at"
    t.integer  "selling_agent_id",             limit: 4
    t.string   "customer_order_status",        limit: 255
    t.text     "processing_errors",            limit: 65535
  end

  add_index "orders", ["accepted_at"], name: "index_orders_on_accepted_at", using: :btree
  add_index "orders", ["accepted_by_id"], name: "index_orders_on_accepted_by_id", using: :btree
  add_index "orders", ["agent_id"], name: "index_orders_on_agent_id", using: :btree
  add_index "orders", ["approval_status"], name: "index_orders_on_approval_status", using: :btree
  add_index "orders", ["closed_at"], name: "index_orders_on_closed_at", using: :btree
  add_index "orders", ["closed_by_id"], name: "index_orders_on_closed_by_id", using: :btree
  add_index "orders", ["factory_id"], name: "index_orders_on_factory_id", using: :btree
  add_index "orders", ["first_expected_delivery_date"], name: "index_orders_on_first_expected_delivery_date", using: :btree
  add_index "orders", ["fob_point"], name: "index_orders_on_fob_point", using: :btree
  add_index "orders", ["importer_id", "customer_order_number"], name: "index_orders_on_importer_id_and_customer_order_number", using: :btree
  add_index "orders", ["order_from_address_id"], name: "index_orders_on_order_from_address_id", using: :btree
  add_index "orders", ["order_number"], name: "index_orders_on_order_number", using: :btree
  add_index "orders", ["season"], name: "index_orders_on_season", using: :btree
  add_index "orders", ["ship_from_id"], name: "index_orders_on_ship_from_id", using: :btree
  add_index "orders", ["ship_window_end"], name: "index_orders_on_ship_window_end", using: :btree
  add_index "orders", ["ship_window_start"], name: "index_orders_on_ship_window_start", using: :btree
  add_index "orders", ["tpp_survey_response_id"], name: "index_orders_on_tpp_survey_response_id", using: :btree

  create_table "part_number_correlations", force: :cascade do |t|
    t.integer  "starting_row",      limit: 4
    t.string   "part_column",       limit: 255
    t.string   "part_regex",        limit: 255
    t.string   "entry_country_iso", limit: 255
    t.string   "importers",         limit: 255
    t.datetime "finished_time"
    t.integer  "user_id",           limit: 4
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
  end

  create_table "pga_summaries", force: :cascade do |t|
    t.integer  "commercial_invoice_tariff_id", limit: 4,   null: false
    t.integer  "sequence_number",              limit: 4
    t.string   "agency_code",                  limit: 255
    t.string   "program_code",                 limit: 255
    t.string   "tariff_regulation_code",       limit: 255
    t.string   "commercial_description",       limit: 255
    t.string   "agency_processing_code",       limit: 255
    t.string   "disclaimer_type_code",         limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "disclaimed"
  end

  add_index "pga_summaries", ["commercial_invoice_tariff_id"], name: "index_pga_summaries_on_commercial_invoice_tariff_id", using: :btree

  create_table "piece_sets", force: :cascade do |t|
    t.integer  "order_line_id",              limit: 4
    t.datetime "created_at",                                                      null: false
    t.datetime "updated_at",                                                      null: false
    t.decimal  "quantity",                               precision: 13, scale: 4
    t.string   "adjustment_type",            limit: 255
    t.integer  "sales_order_line_id",        limit: 4
    t.boolean  "unshipped_remainder"
    t.integer  "shipment_line_id",           limit: 4
    t.integer  "delivery_line_id",           limit: 4
    t.integer  "milestone_plan_id",          limit: 4
    t.integer  "drawback_import_line_id",    limit: 4
    t.integer  "commercial_invoice_line_id", limit: 4
    t.integer  "security_filing_line_id",    limit: 4
    t.integer  "booking_line_id",            limit: 4
  end

  add_index "piece_sets", ["commercial_invoice_line_id"], name: "index_piece_sets_on_commercial_invoice_line_id", using: :btree
  add_index "piece_sets", ["drawback_import_line_id"], name: "index_piece_sets_on_drawback_import_line_id", using: :btree
  add_index "piece_sets", ["order_line_id"], name: "index_piece_sets_on_order_line_id", using: :btree
  add_index "piece_sets", ["security_filing_line_id"], name: "index_piece_sets_on_security_filing_line_id", using: :btree
  add_index "piece_sets", ["shipment_line_id"], name: "index_piece_sets_on_shipment_line_id", using: :btree

  create_table "plant_product_group_assignments", force: :cascade do |t|
    t.integer  "plant_id",         limit: 4
    t.integer  "product_group_id", limit: 4
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
  end

  add_index "plant_product_group_assignments", ["plant_id"], name: "index_plant_product_group_assignments_on_plant_id", using: :btree
  add_index "plant_product_group_assignments", ["product_group_id"], name: "index_plant_product_group_assignments_on_product_group_id", using: :btree

  create_table "plant_variant_assignments", force: :cascade do |t|
    t.integer  "plant_id",   limit: 4, null: false
    t.integer  "variant_id", limit: 4, null: false
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
    t.boolean  "disabled"
  end

  add_index "plant_variant_assignments", ["disabled"], name: "index_plant_variant_assignments_on_disabled", using: :btree
  add_index "plant_variant_assignments", ["plant_id", "disabled"], name: "index_plant_variant_assignments_on_plant_id_and_disabled", using: :btree
  add_index "plant_variant_assignments", ["plant_id"], name: "index_plant_variant_assignments_on_plant_id", using: :btree
  add_index "plant_variant_assignments", ["variant_id", "disabled"], name: "index_plant_variant_assignments_on_variant_id_and_disabled", using: :btree
  add_index "plant_variant_assignments", ["variant_id"], name: "index_plant_variant_assignments_on_variant_id", using: :btree

  create_table "plants", force: :cascade do |t|
    t.string   "name",       limit: 255
    t.integer  "company_id", limit: 4
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "plants", ["company_id"], name: "index_plants_on_company_id", using: :btree

  create_table "ports", force: :cascade do |t|
    t.string   "schedule_d_code",    limit: 255
    t.string   "schedule_k_code",    limit: 255
    t.string   "name",               limit: 255
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
    t.string   "cbsa_port",          limit: 255
    t.string   "cbsa_sublocation",   limit: 255
    t.string   "unlocode",           limit: 255
    t.boolean  "active_origin"
    t.boolean  "active_destination"
    t.string   "iata_code",          limit: 255
  end

  add_index "ports", ["cbsa_port"], name: "index_ports_on_cbsa_port", using: :btree
  add_index "ports", ["cbsa_sublocation"], name: "index_ports_on_cbsa_sublocation", using: :btree
  add_index "ports", ["iata_code"], name: "index_ports_on_iata_code", using: :btree
  add_index "ports", ["name"], name: "index_ports_on_name", using: :btree
  add_index "ports", ["schedule_d_code"], name: "index_ports_on_schedule_d_code", using: :btree
  add_index "ports", ["schedule_k_code"], name: "index_ports_on_schedule_k_code", using: :btree
  add_index "ports", ["unlocode"], name: "index_ports_on_unlocode", using: :btree

  create_table "power_of_attorneys", force: :cascade do |t|
    t.integer  "company_id",              limit: 4
    t.date     "start_date"
    t.date     "expiration_date"
    t.integer  "uploaded_by",             limit: 4
    t.string   "attachment_file_name",    limit: 255
    t.string   "attachment_content_type", limit: 255
    t.integer  "attachment_file_size",    limit: 4
    t.datetime "attachment_updated_at"
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
  end

  create_table "product_factories", force: :cascade do |t|
    t.integer "product_id", limit: 4
    t.integer "address_id", limit: 4
  end

  add_index "product_factories", ["address_id", "product_id"], name: "index_product_factories_on_address_id_and_product_id", using: :btree
  add_index "product_factories", ["product_id", "address_id"], name: "index_product_factories_on_product_id_and_address_id", unique: true, using: :btree

  create_table "product_groups", force: :cascade do |t|
    t.string   "name",       limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  create_table "product_rate_overrides", force: :cascade do |t|
    t.integer  "product_id",             limit: 4
    t.integer  "origin_country_id",      limit: 4
    t.integer  "destination_country_id", limit: 4
    t.decimal  "rate",                                 precision: 8, scale: 4
    t.date     "start_date"
    t.date     "end_date"
    t.text     "notes",                  limit: 65535
    t.datetime "created_at",                                                   null: false
    t.datetime "updated_at",                                                   null: false
  end

  add_index "product_rate_overrides", ["origin_country_id", "destination_country_id"], name: "countries", using: :btree
  add_index "product_rate_overrides", ["product_id"], name: "prod_id", using: :btree
  add_index "product_rate_overrides", ["start_date", "end_date"], name: "start_end", using: :btree

  create_table "product_trade_preference_programs", force: :cascade do |t|
    t.integer  "product_id",                  limit: 4
    t.integer  "trade_preference_program_id", limit: 4
    t.datetime "created_at",                            null: false
    t.datetime "updated_at",                            null: false
  end

  add_index "product_trade_preference_programs", ["product_id"], name: "ptpp_product_id", using: :btree
  add_index "product_trade_preference_programs", ["trade_preference_program_id"], name: "ptpp_trade_pref_id", using: :btree

  create_table "product_vendor_assignments", force: :cascade do |t|
    t.integer  "product_id", limit: 4
    t.integer  "vendor_id",  limit: 4
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
  end

  add_index "product_vendor_assignments", ["product_id"], name: "index_product_vendor_assignments_on_product_id", using: :btree
  add_index "product_vendor_assignments", ["vendor_id", "product_id"], name: "index_product_vendor_assignments_on_vendor_id_and_product_id", unique: true, using: :btree
  add_index "product_vendor_assignments", ["vendor_id"], name: "index_product_vendor_assignments_on_vendor_id", using: :btree

  create_table "products", force: :cascade do |t|
    t.string   "unique_identifier",         limit: 255
    t.string   "name",                      limit: 255
    t.datetime "created_at",                                            null: false
    t.datetime "updated_at",                                            null: false
    t.integer  "division_id",               limit: 4
    t.string   "unit_of_measure",           limit: 255
    t.integer  "status_rule_id",            limit: 4
    t.datetime "changed_at"
    t.integer  "entity_type_id",            limit: 4
    t.integer  "last_updated_by_id",        limit: 4
    t.integer  "importer_id",               limit: 4
    t.string   "last_file_bucket",          limit: 255
    t.string   "last_file_path",            limit: 255
    t.boolean  "inactive",                              default: false
    t.datetime "last_exported_from_source"
  end

  add_index "products", ["changed_at"], name: "index_products_on_changed_at", using: :btree
  add_index "products", ["importer_id"], name: "index_products_on_importer_id", using: :btree
  add_index "products", ["name"], name: "index_products_on_name", using: :btree
  add_index "products", ["unique_identifier"], name: "index_products_on_unique_identifier", using: :btree

  create_table "public_fields", force: :cascade do |t|
    t.string   "model_field_uid", limit: 255
    t.boolean  "searchable"
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
  end

  add_index "public_fields", ["model_field_uid"], name: "index_public_fields_on_model_field_uid", using: :btree

  create_table "questions", force: :cascade do |t|
    t.integer  "survey_id",                       limit: 4
    t.integer  "rank",                            limit: 4
    t.text     "choices",                         limit: 65535
    t.text     "content",                         limit: 65535
    t.datetime "created_at",                                                    null: false
    t.datetime "updated_at",                                                    null: false
    t.boolean  "warning"
    t.boolean  "require_attachment",                            default: false
    t.boolean  "require_comment",                               default: false
    t.string   "attachment_required_for_choices", limit: 255
    t.string   "comment_required_for_choices",    limit: 255
  end

  add_index "questions", ["survey_id"], name: "index_questions_on_survey_id", using: :btree

  create_table "random_audits", force: :cascade do |t|
    t.integer  "user_id",               limit: 4
    t.integer  "search_setup_id",       limit: 4
    t.string   "attached_content_type", limit: 255
    t.integer  "attached_file_size",    limit: 4
    t.string   "attached_file_name",    limit: 255
    t.datetime "attached_updated_at"
    t.string   "module_type",           limit: 255
    t.string   "report_name",           limit: 255
    t.datetime "report_date"
    t.datetime "created_at",                        null: false
    t.datetime "updated_at",                        null: false
  end

  create_table "regions", force: :cascade do |t|
    t.string   "name",       limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  create_table "report_results", force: :cascade do |t|
    t.string   "name",                     limit: 255
    t.datetime "run_at"
    t.text     "friendly_settings_json",   limit: 65535
    t.text     "settings_json",            limit: 65535
    t.string   "report_class",             limit: 255
    t.string   "report_data_file_name",    limit: 255
    t.string   "report_data_content_type", limit: 255
    t.integer  "report_data_file_size",    limit: 4
    t.datetime "report_data_updated_at"
    t.string   "status",                   limit: 255
    t.text     "run_errors",               limit: 65535
    t.integer  "run_by_id",                limit: 4
    t.datetime "created_at",                             null: false
    t.datetime "updated_at",                             null: false
    t.integer  "custom_report_id",         limit: 4
    t.string   "email_to",                 limit: 255
  end

  add_index "report_results", ["custom_report_id"], name: "index_report_results_on_custom_report_id", using: :btree
  add_index "report_results", ["run_by_id"], name: "index_report_results_on_run_by_id", using: :btree

  create_table "request_logs", force: :cascade do |t|
    t.integer  "user_id",           limit: 4
    t.string   "http_method",       limit: 255
    t.text     "url",               limit: 65535
    t.integer  "run_as_session_id", limit: 4
    t.datetime "created_at",                      null: false
    t.datetime "updated_at",                      null: false
  end

  add_index "request_logs", ["run_as_session_id"], name: "index_request_logs_on_run_as_session_id", using: :btree
  add_index "request_logs", ["user_id"], name: "index_request_logs_on_user_id", using: :btree

  create_table "result_caches", force: :cascade do |t|
    t.integer  "result_cacheable_id",   limit: 4
    t.string   "result_cacheable_type", limit: 255
    t.integer  "page",                  limit: 4
    t.integer  "per_page",              limit: 4
    t.text     "object_ids",            limit: 65535
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
  end

  add_index "result_caches", ["result_cacheable_id", "result_cacheable_type"], name: "result_cacheable", using: :btree

  create_table "run_as_sessions", force: :cascade do |t|
    t.integer  "user_id",        limit: 4
    t.integer  "run_as_user_id", limit: 4
    t.datetime "start_time"
    t.datetime "end_time"
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
  end

  add_index "run_as_sessions", ["run_as_user_id"], name: "index_run_as_sessions_on_run_as_user_id", using: :btree
  add_index "run_as_sessions", ["start_time"], name: "index_run_as_sessions_on_start_time", using: :btree
  add_index "run_as_sessions", ["user_id"], name: "index_run_as_sessions_on_user_id", using: :btree

  create_table "runtime_logs", force: :cascade do |t|
    t.datetime "start"
    t.datetime "end"
    t.string   "identifier",           limit: 255
    t.integer  "runtime_logable_id",   limit: 4
    t.string   "runtime_logable_type", limit: 255
    t.datetime "created_at",                       null: false
    t.datetime "updated_at",                       null: false
  end

  add_index "runtime_logs", ["created_at"], name: "index_runtime_logs_on_created_at", using: :btree
  add_index "runtime_logs", ["runtime_logable_type", "runtime_logable_id"], name: "index_runtime_logs_on_runtime_logable", using: :btree

  create_table "sales_order_lines", force: :cascade do |t|
    t.decimal  "price_per_unit",           precision: 13, scale: 4
    t.integer  "sales_order_id", limit: 4
    t.integer  "line_number",    limit: 4
    t.datetime "created_at",                                        null: false
    t.datetime "updated_at",                                        null: false
    t.integer  "product_id",     limit: 4
    t.decimal  "quantity",                 precision: 13, scale: 4
  end

  add_index "sales_order_lines", ["sales_order_id"], name: "index_sales_order_lines_on_sales_order_id", using: :btree

  create_table "sales_orders", force: :cascade do |t|
    t.string   "order_number", limit: 255
    t.date     "order_date"
    t.integer  "customer_id",  limit: 4
    t.integer  "division_id",  limit: 4
    t.integer  "ship_to_id",   limit: 4
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
  end

  create_table "schedulable_jobs", force: :cascade do |t|
    t.boolean  "run_monday"
    t.boolean  "run_tuesday"
    t.boolean  "run_wednesday"
    t.boolean  "run_thursday"
    t.boolean  "run_friday"
    t.boolean  "run_saturday"
    t.boolean  "run_sunday"
    t.integer  "run_hour",           limit: 4
    t.integer  "run_minute",         limit: 4
    t.integer  "day_of_month",       limit: 4
    t.string   "time_zone_name",     limit: 255
    t.string   "run_class",          limit: 255
    t.text     "opts",               limit: 65535
    t.datetime "created_at",                                       null: false
    t.datetime "updated_at",                                       null: false
    t.datetime "last_start_time"
    t.string   "success_email",      limit: 255
    t.string   "failure_email",      limit: 255
    t.string   "run_interval",       limit: 255
    t.boolean  "no_concurrent_jobs"
    t.boolean  "running"
    t.boolean  "stopped"
    t.integer  "queue_priority",     limit: 4
    t.text     "notes",              limit: 65535
    t.boolean  "log_runtime",                      default: false
  end

  create_table "schedule_servers", force: :cascade do |t|
    t.string   "host",       limit: 255
    t.datetime "touch_time"
  end

  create_table "search_columns", force: :cascade do |t|
    t.integer  "search_setup_id",      limit: 4
    t.integer  "rank",                 limit: 4
    t.string   "model_field_uid",      limit: 255
    t.integer  "custom_definition_id", limit: 4
    t.datetime "created_at",                       null: false
    t.datetime "updated_at",                       null: false
    t.integer  "imported_file_id",     limit: 4
    t.integer  "custom_report_id",     limit: 4
    t.string   "constant_field_name",  limit: 255
    t.string   "constant_field_value", limit: 255
  end

  add_index "search_columns", ["custom_report_id"], name: "index_search_columns_on_custom_report_id", using: :btree
  add_index "search_columns", ["imported_file_id"], name: "index_search_columns_on_imported_file_id", using: :btree
  add_index "search_columns", ["search_setup_id"], name: "index_search_columns_on_search_setup_id", using: :btree

  create_table "search_criterions", force: :cascade do |t|
    t.string   "operator",                         limit: 255
    t.text     "value",                            limit: 65535
    t.datetime "created_at",                                     null: false
    t.datetime "updated_at",                                     null: false
    t.integer  "status_rule_id",                   limit: 4
    t.string   "model_field_uid",                  limit: 255
    t.integer  "search_setup_id",                  limit: 4
    t.integer  "custom_definition_id",             limit: 4
    t.integer  "instant_classification_id",        limit: 4
    t.integer  "imported_file_id",                 limit: 4
    t.integer  "search_run_id",                    limit: 4
    t.integer  "custom_report_id",                 limit: 4
    t.boolean  "include_empty"
    t.integer  "business_validation_template_id",  limit: 4
    t.integer  "business_validation_rule_id",      limit: 4
    t.integer  "state_toggle_button_id",           limit: 4
    t.integer  "milestone_notification_config_id", limit: 4
    t.integer  "automated_billing_setup_id",       limit: 4
    t.integer  "custom_view_template_id",          limit: 4
    t.string   "secondary_model_field_uid",        limit: 255
    t.integer  "one_time_alert_id",                limit: 4
    t.integer  "business_validation_schedule_id",  limit: 4
  end

  add_index "search_criterions", ["automated_billing_setup_id"], name: "index_search_criterions_on_automated_billing_setup_id", using: :btree
  add_index "search_criterions", ["business_validation_rule_id"], name: "business_validation_rule", using: :btree
  add_index "search_criterions", ["business_validation_template_id"], name: "business_validation_template", using: :btree
  add_index "search_criterions", ["custom_report_id"], name: "index_search_criterions_on_custom_report_id", using: :btree
  add_index "search_criterions", ["custom_view_template_id"], name: "index_search_criterions_on_custom_view_template_id", using: :btree
  add_index "search_criterions", ["imported_file_id"], name: "index_search_criterions_on_imported_file_id", using: :btree
  add_index "search_criterions", ["milestone_notification_config_id"], name: "index_search_criterions_on_milestone_notification_config_id", using: :btree
  add_index "search_criterions", ["search_run_id"], name: "index_search_criterions_on_search_run_id", using: :btree
  add_index "search_criterions", ["search_setup_id"], name: "index_search_criterions_on_search_setup_id", using: :btree
  add_index "search_criterions", ["state_toggle_button_id"], name: "index_search_criterions_on_state_toggle_button_id", using: :btree

  create_table "search_runs", force: :cascade do |t|
    t.integer  "search_setup_id",         limit: 4
    t.datetime "created_at",                        null: false
    t.datetime "updated_at",                        null: false
    t.integer  "starting_cache_position", limit: 4
    t.datetime "last_accessed"
    t.integer  "imported_file_id",        limit: 4
    t.integer  "user_id",                 limit: 4
    t.integer  "custom_file_id",          limit: 4
    t.integer  "page",                    limit: 4
    t.integer  "per_page",                limit: 4
  end

  add_index "search_runs", ["custom_file_id"], name: "cf_id", using: :btree
  add_index "search_runs", ["user_id", "last_accessed"], name: "index_search_runs_on_user_id_and_last_accessed", using: :btree

  create_table "search_schedules", force: :cascade do |t|
    t.string   "email_addresses",        limit: 255
    t.string   "ftp_server",             limit: 255
    t.string   "ftp_username",           limit: 255
    t.string   "ftp_password",           limit: 255
    t.string   "ftp_subfolder",          limit: 255
    t.boolean  "run_monday"
    t.boolean  "run_tuesday"
    t.boolean  "run_wednesday"
    t.boolean  "run_thursday"
    t.boolean  "run_friday"
    t.boolean  "run_saturday"
    t.boolean  "run_sunday"
    t.integer  "run_hour",               limit: 4
    t.datetime "last_start_time"
    t.datetime "last_finish_time"
    t.integer  "search_setup_id",        limit: 4
    t.datetime "created_at",                                         null: false
    t.datetime "updated_at",                                         null: false
    t.string   "download_format",        limit: 255
    t.integer  "day_of_month",           limit: 4
    t.integer  "custom_report_id",       limit: 4
    t.string   "protocol",               limit: 255
    t.boolean  "send_if_empty"
    t.boolean  "exclude_file_timestamp"
    t.string   "ftp_port",               limit: 255
    t.integer  "report_failure_count",   limit: 4,   default: 0
    t.boolean  "disabled"
    t.integer  "mailing_list_id",        limit: 4
    t.boolean  "log_runtime",                        default: false
    t.string   "date_format",            limit: 255
  end

  add_index "search_schedules", ["custom_report_id"], name: "index_search_schedules_on_custom_report_id", using: :btree
  add_index "search_schedules", ["search_setup_id"], name: "index_search_schedules_on_search_setup_id", using: :btree

  create_table "search_setups", force: :cascade do |t|
    t.string   "name",               limit: 255
    t.integer  "user_id",            limit: 4
    t.string   "module_type",        limit: 255
    t.boolean  "simple"
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
    t.string   "download_format",    limit: 255
    t.boolean  "include_links"
    t.boolean  "no_time"
    t.boolean  "include_rule_links"
    t.boolean  "locked"
    t.string   "date_format",        limit: 255
  end

  add_index "search_setups", ["user_id", "module_type"], name: "index_search_setups_on_user_id_and_module_type", using: :btree

  create_table "search_table_configs", force: :cascade do |t|
    t.string   "page_uid",    limit: 255
    t.string   "name",        limit: 255
    t.text     "config_json", limit: 65535
    t.integer  "user_id",     limit: 4
    t.integer  "company_id",  limit: 4
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
  end

  add_index "search_table_configs", ["company_id"], name: "index_search_table_configs_on_company_id", using: :btree
  add_index "search_table_configs", ["page_uid"], name: "index_search_table_configs_on_page_uid", using: :btree
  add_index "search_table_configs", ["user_id"], name: "index_search_table_configs_on_user_id", using: :btree

  create_table "search_templates", force: :cascade do |t|
    t.string   "name",        limit: 255
    t.string   "module_type", limit: 255
    t.text     "search_json", limit: 65535
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
  end

  create_table "security_filing_lines", force: :cascade do |t|
    t.integer  "security_filing_id",        limit: 4
    t.integer  "line_number",               limit: 4
    t.integer  "quantity",                  limit: 4
    t.string   "hts_code",                  limit: 255
    t.string   "part_number",               limit: 255
    t.string   "po_number",                 limit: 255
    t.string   "commercial_invoice_number", limit: 255
    t.string   "mid",                       limit: 255
    t.string   "country_of_origin_code",    limit: 255
    t.datetime "created_at",                            null: false
    t.datetime "updated_at",                            null: false
    t.string   "manufacturer_name",         limit: 255
  end

  add_index "security_filing_lines", ["part_number"], name: "index_security_filing_lines_on_part_number", using: :btree
  add_index "security_filing_lines", ["po_number"], name: "index_security_filing_lines_on_po_number", using: :btree
  add_index "security_filing_lines", ["security_filing_id"], name: "index_security_filing_lines_on_security_filing_id", using: :btree

  create_table "security_filings", force: :cascade do |t|
    t.string   "transaction_number",            limit: 255
    t.string   "host_system_file_number",       limit: 255
    t.string   "host_system",                   limit: 255
    t.integer  "importer_id",                   limit: 4
    t.string   "importer_account_code",         limit: 255
    t.string   "broker_customer_number",        limit: 255
    t.string   "importer_tax_id",               limit: 255
    t.string   "transport_mode_code",           limit: 255
    t.string   "scac",                          limit: 255
    t.string   "booking_number",                limit: 255
    t.string   "vessel",                        limit: 255
    t.string   "voyage",                        limit: 255
    t.string   "lading_port_code",              limit: 255
    t.string   "unlading_port_code",            limit: 255
    t.string   "entry_port_code",               limit: 255
    t.string   "status_code",                   limit: 255
    t.boolean  "late_filing"
    t.string   "master_bill_of_lading",         limit: 255
    t.string   "house_bills_of_lading",         limit: 255
    t.string   "container_numbers",             limit: 255
    t.string   "entry_numbers",                 limit: 255
    t.string   "entry_reference_numbers",       limit: 255
    t.datetime "file_logged_date"
    t.datetime "first_sent_date"
    t.datetime "first_accepted_date"
    t.datetime "last_sent_date"
    t.datetime "last_accepted_date"
    t.date     "estimated_vessel_load_date"
    t.string   "po_numbers",                    limit: 255
    t.datetime "created_at",                                  null: false
    t.datetime "updated_at",                                  null: false
    t.text     "notes",                         limit: 65535
    t.datetime "last_event"
    t.string   "last_file_bucket",              limit: 255
    t.string   "last_file_path",                limit: 255
    t.integer  "time_to_process",               limit: 4
    t.date     "estimated_vessel_arrival_date"
    t.text     "countries_of_origin",           limit: 65535
    t.date     "estimated_vessel_sailing_date"
    t.datetime "cbp_updated_at"
    t.string   "status_description",            limit: 255
    t.text     "manufacturer_names",            limit: 65535
    t.datetime "ams_match_date"
    t.datetime "delete_accepted_date"
    t.datetime "us_customs_first_file_date"
    t.datetime "vessel_departure_date"
  end

  add_index "security_filings", ["container_numbers"], name: "index_security_filings_on_container_numbers", using: :btree
  add_index "security_filings", ["entry_numbers"], name: "index_security_filings_on_entry_numbers", using: :btree
  add_index "security_filings", ["entry_reference_numbers"], name: "index_security_filings_on_entry_reference_numbers", using: :btree
  add_index "security_filings", ["estimated_vessel_load_date"], name: "index_security_filings_on_estimated_vessel_load_date", using: :btree
  add_index "security_filings", ["first_accepted_date"], name: "index_security_filings_on_first_accepted_date", using: :btree
  add_index "security_filings", ["first_sent_date"], name: "index_security_filings_on_first_sent_date", using: :btree
  add_index "security_filings", ["host_system"], name: "index_security_filings_on_host_system", using: :btree
  add_index "security_filings", ["host_system_file_number"], name: "index_security_filings_on_host_system_file_number", using: :btree
  add_index "security_filings", ["house_bills_of_lading"], name: "index_security_filings_on_house_bills_of_lading", using: :btree
  add_index "security_filings", ["importer_id"], name: "index_security_filings_on_importer_id", using: :btree
  add_index "security_filings", ["master_bill_of_lading"], name: "index_security_filings_on_master_bill_of_lading", using: :btree
  add_index "security_filings", ["po_numbers"], name: "index_security_filings_on_po_numbers", using: :btree
  add_index "security_filings", ["transaction_number"], name: "index_security_filings_on_transaction_number", using: :btree

  create_table "sent_emails", force: :cascade do |t|
    t.string   "email_subject",  limit: 255
    t.string   "email_to",       limit: 255
    t.string   "email_cc",       limit: 255
    t.string   "email_bcc",      limit: 255
    t.string   "email_from",     limit: 255
    t.string   "email_reply_to", limit: 255
    t.datetime "email_date"
    t.text     "email_body",     limit: 65535
    t.datetime "created_at",                                   null: false
    t.datetime "updated_at",                                   null: false
    t.boolean  "suppressed",                   default: false
    t.text     "delivery_error", limit: 65535
  end

  create_table "shipment_lines", force: :cascade do |t|
    t.integer  "line_number",             limit: 4
    t.datetime "created_at",                                                   null: false
    t.datetime "updated_at",                                                   null: false
    t.integer  "shipment_id",             limit: 4
    t.integer  "product_id",              limit: 4
    t.decimal  "quantity",                            precision: 13, scale: 4
    t.integer  "container_id",            limit: 4
    t.decimal  "gross_kgs",                           precision: 13, scale: 4
    t.decimal  "cbms",                                precision: 13, scale: 4
    t.integer  "carton_qty",              limit: 4
    t.integer  "carton_set_id",           limit: 4
    t.string   "fcr_number",              limit: 255
    t.integer  "canceled_order_line_id",  limit: 4
    t.integer  "manufacturer_address_id", limit: 4
    t.integer  "variant_id",              limit: 4
    t.string   "master_bill_of_lading",   limit: 255
    t.string   "invoice_number",          limit: 255
    t.string   "mid",                     limit: 255
    t.decimal  "net_weight",                          precision: 11, scale: 2
    t.string   "net_weight_uom",          limit: 255
  end

  add_index "shipment_lines", ["carton_set_id"], name: "index_shipment_lines_on_carton_set_id", using: :btree
  add_index "shipment_lines", ["container_id"], name: "index_shipment_lines_on_container_id", using: :btree
  add_index "shipment_lines", ["fcr_number"], name: "index_shipment_lines_on_fcr_number", using: :btree
  add_index "shipment_lines", ["product_id"], name: "index_shipment_lines_on_product_id", using: :btree
  add_index "shipment_lines", ["shipment_id"], name: "index_shipment_lines_on_shipment_id", using: :btree
  add_index "shipment_lines", ["variant_id"], name: "index_shipment_lines_on_variant_id", using: :btree

  create_table "shipments", force: :cascade do |t|
    t.integer  "ship_from_id",                     limit: 4
    t.integer  "ship_to_id",                       limit: 4
    t.integer  "carrier_id",                       limit: 4
    t.datetime "created_at",                                                              null: false
    t.datetime "updated_at",                                                              null: false
    t.string   "reference",                        limit: 255
    t.string   "mode",                             limit: 255
    t.integer  "vendor_id",                        limit: 4
    t.integer  "importer_id",                      limit: 4
    t.string   "master_bill_of_lading",            limit: 255
    t.string   "house_bill_of_lading",             limit: 255
    t.string   "booking_number",                   limit: 255
    t.string   "receipt_location",                 limit: 255
    t.integer  "lading_port_id",                   limit: 4
    t.integer  "unlading_port_id",                 limit: 4
    t.integer  "entry_port_id",                    limit: 4
    t.integer  "destination_port_id",              limit: 4
    t.string   "freight_terms",                    limit: 255
    t.boolean  "lcl"
    t.string   "shipment_type",                    limit: 255
    t.string   "booking_shipment_type",            limit: 255
    t.string   "booking_mode",                     limit: 255
    t.string   "vessel",                           limit: 255
    t.string   "voyage",                           limit: 255
    t.string   "vessel_carrier_scac",              limit: 255
    t.datetime "booking_received_date"
    t.datetime "booking_confirmed_date"
    t.date     "booking_cutoff_date"
    t.date     "booking_est_arrival_date"
    t.date     "booking_est_departure_date"
    t.date     "docs_received_date"
    t.date     "cargo_on_hand_date"
    t.date     "est_departure_date"
    t.date     "departure_date"
    t.date     "est_arrival_port_date"
    t.date     "arrival_port_date"
    t.date     "est_delivery_date"
    t.date     "delivered_date"
    t.date     "cargo_on_board_date"
    t.datetime "last_exported_from_source"
    t.string   "importer_reference",               limit: 255
    t.date     "cargo_ready_date"
    t.integer  "booking_requested_by_id",          limit: 4
    t.integer  "booking_confirmed_by_id",          limit: 4
    t.datetime "booking_approved_date"
    t.integer  "booking_approved_by_id",           limit: 4
    t.decimal  "booked_quantity",                                precision: 11, scale: 2
    t.datetime "canceled_date"
    t.integer  "canceled_by_id",                   limit: 4
    t.string   "vessel_nationality",               limit: 255
    t.integer  "first_port_receipt_id",            limit: 4
    t.integer  "last_foreign_port_id",             limit: 4
    t.text     "marks_and_numbers",                limit: 65535
    t.integer  "number_of_packages",               limit: 4
    t.string   "number_of_packages_uom",           limit: 255
    t.decimal  "gross_weight",                                   precision: 9,  scale: 2
    t.string   "booking_carrier",                  limit: 255
    t.string   "booking_vessel",                   limit: 255
    t.string   "delay_reason_codes",               limit: 255
    t.date     "shipment_cutoff_date"
    t.boolean  "fish_and_wildlife"
    t.decimal  "volume",                                         precision: 9,  scale: 2
    t.datetime "cancel_requested_at"
    t.integer  "cancel_requested_by_id",           limit: 4
    t.integer  "seller_address_id",                limit: 4
    t.integer  "buyer_address_id",                 limit: 4
    t.integer  "ship_to_address_id",               limit: 4
    t.integer  "container_stuffing_address_id",    limit: 4
    t.integer  "consolidator_address_id",          limit: 4
    t.integer  "consignee_id",                     limit: 4
    t.datetime "isf_sent_at"
    t.integer  "isf_sent_by_id",                   limit: 4
    t.date     "est_load_date"
    t.integer  "final_dest_port_id",               limit: 4
    t.date     "confirmed_on_board_origin_date"
    t.date     "eta_last_foreign_port_date"
    t.date     "departure_last_foreign_port_date"
    t.datetime "booking_revised_date"
    t.integer  "booking_revised_by_id",            limit: 4
    t.decimal  "freight_total",                                  precision: 11, scale: 2
    t.decimal  "invoice_total",                                  precision: 11, scale: 2
    t.integer  "inland_destination_port_id",       limit: 4
    t.date     "est_inland_port_date"
    t.date     "inland_port_date"
    t.text     "requested_equipment",              limit: 65535
    t.integer  "forwarder_id",                     limit: 4
    t.date     "booking_cargo_ready_date"
    t.integer  "booking_first_port_receipt_id",    limit: 4
    t.string   "booking_requested_equipment",      limit: 255
    t.integer  "booking_request_count",            limit: 4
    t.boolean  "hazmat"
    t.boolean  "solid_wood_packing_materials"
    t.boolean  "lacey_act"
    t.boolean  "export_license_required"
    t.date     "shipment_instructions_sent_date"
    t.integer  "shipment_instructions_sent_by_id", limit: 4
    t.string   "last_file_bucket",                 limit: 255
    t.string   "last_file_path",                   limit: 255
    t.date     "do_issued_at"
    t.string   "trucker_name",                     limit: 255
    t.date     "port_last_free_day"
    t.date     "pickup_at"
    t.datetime "in_warehouse_time"
    t.string   "booking_voyage",                   limit: 255
    t.datetime "packing_list_sent_date"
    t.integer  "packing_list_sent_by_id",          limit: 4
    t.datetime "vgm_sent_date"
    t.integer  "vgm_sent_by_id",                   limit: 4
    t.integer  "country_origin_id",                limit: 4
    t.datetime "warning_overridden_at"
    t.integer  "warning_overridden_by_id",         limit: 4
    t.datetime "empty_out_at_origin_date"
    t.datetime "empty_return_date"
    t.datetime "container_unloaded_date"
    t.datetime "carrier_released_date"
    t.datetime "customs_released_carrier_date"
    t.datetime "available_for_delivery_date"
    t.datetime "full_ingate_date"
    t.datetime "full_out_gate_discharge_date"
    t.datetime "on_rail_destination_date"
    t.datetime "full_container_discharge_date"
    t.datetime "arrive_at_transship_port_date"
    t.datetime "barge_depart_date"
    t.datetime "barge_arrive_date"
    t.datetime "fcr_created_final_date"
    t.datetime "bol_date"
    t.integer  "country_export_id",                limit: 4
    t.integer  "country_import_id",                limit: 4
    t.string   "description_of_goods",             limit: 255
  end

  add_index "shipments", ["arrival_port_date"], name: "index_shipments_on_arrival_port_date", using: :btree
  add_index "shipments", ["booking_approved_by_id"], name: "index_shipments_on_booking_approved_by_id", using: :btree
  add_index "shipments", ["booking_cargo_ready_date"], name: "index_shipments_on_booking_cargo_ready_date", using: :btree
  add_index "shipments", ["booking_confirmed_by_id"], name: "index_shipments_on_booking_confirmed_by_id", using: :btree
  add_index "shipments", ["booking_number"], name: "index_shipments_on_booking_number", using: :btree
  add_index "shipments", ["booking_request_count"], name: "index_shipments_on_booking_request_count", using: :btree
  add_index "shipments", ["booking_requested_by_id"], name: "index_shipments_on_booking_requested_by_id", using: :btree
  add_index "shipments", ["canceled_by_id"], name: "index_shipments_on_canceled_by_id", using: :btree
  add_index "shipments", ["canceled_date"], name: "index_shipments_on_canceled_date", using: :btree
  add_index "shipments", ["departure_date"], name: "index_shipments_on_departure_date", using: :btree
  add_index "shipments", ["est_arrival_port_date"], name: "index_shipments_on_est_arrival_port_date", using: :btree
  add_index "shipments", ["est_departure_date"], name: "index_shipments_on_est_departure_date", using: :btree
  add_index "shipments", ["forwarder_id"], name: "index_shipments_on_forwarder_id", using: :btree
  add_index "shipments", ["house_bill_of_lading"], name: "index_shipments_on_house_bill_of_lading", using: :btree
  add_index "shipments", ["importer_id"], name: "index_shipments_on_importer_id", using: :btree
  add_index "shipments", ["importer_reference"], name: "index_shipments_on_importer_reference", using: :btree
  add_index "shipments", ["inland_destination_port_id"], name: "index_shipments_on_inland_destination_port_id", using: :btree
  add_index "shipments", ["master_bill_of_lading"], name: "index_shipments_on_master_bill_of_lading", using: :btree
  add_index "shipments", ["mode"], name: "index_shipments_on_mode", using: :btree
  add_index "shipments", ["reference"], name: "index_shipments_on_reference", using: :btree

  create_table "sort_criterions", force: :cascade do |t|
    t.integer  "search_setup_id",      limit: 4
    t.integer  "rank",                 limit: 4
    t.string   "model_field_uid",      limit: 255
    t.integer  "custom_definition_id", limit: 4
    t.boolean  "descending"
    t.datetime "created_at",                       null: false
    t.datetime "updated_at",                       null: false
  end

  add_index "sort_criterions", ["search_setup_id"], name: "index_sort_criterions_on_search_setup_id", using: :btree

  create_table "special_tariff_cross_references", force: :cascade do |t|
    t.string   "hts_number",           limit: 255
    t.string   "special_hts_number",   limit: 255
    t.string   "country_origin_iso",   limit: 255
    t.date     "effective_date_start"
    t.date     "effective_date_end"
    t.datetime "created_at",                                       null: false
    t.datetime "updated_at",                                       null: false
    t.string   "import_country_iso",   limit: 255
    t.integer  "priority",             limit: 4
    t.string   "special_tariff_type",  limit: 255
    t.boolean  "suppress_from_feeds",              default: false
  end

  add_index "special_tariff_cross_references", ["hts_number", "country_origin_iso", "effective_date_start"], name: "index_special_tariff_cross_references_on_hts_country_start_date", using: :btree
  add_index "special_tariff_cross_references", ["import_country_iso", "effective_date_start", "country_origin_iso", "special_tariff_type"], name: "by_import_country_effective_date_country_origin_tariff_type", using: :btree
  add_index "special_tariff_cross_references", ["special_hts_number", "effective_date_start", "effective_date_end"], name: "hts_date_index", using: :btree

  create_table "spi_rates", force: :cascade do |t|
    t.integer  "country_id",       limit: 4
    t.string   "special_rate_key", limit: 255
    t.string   "program_code",     limit: 255
    t.decimal  "rate",                         precision: 8, scale: 4
    t.string   "rate_text",        limit: 255
    t.datetime "created_at",                                           null: false
    t.datetime "updated_at",                                           null: false
  end

  add_index "spi_rates", ["country_id"], name: "index_spi_rates_on_country_id", using: :btree
  add_index "spi_rates", ["program_code"], name: "index_spi_rates_on_program_code", using: :btree
  add_index "spi_rates", ["special_rate_key", "country_id", "program_code"], name: "srk_ici_pc", using: :btree

  create_table "state_toggle_buttons", force: :cascade do |t|
    t.string   "module_type",                   limit: 255
    t.string   "user_attribute",                limit: 255
    t.integer  "user_custom_definition_id",     limit: 4
    t.string   "date_attribute",                limit: 255
    t.integer  "date_custom_definition_id",     limit: 4
    t.text     "permission_group_system_codes", limit: 65535
    t.string   "activate_text",                 limit: 255
    t.string   "activate_confirmation_text",    limit: 255
    t.string   "deactivate_text",               limit: 255
    t.string   "deactivate_confirmation_text",  limit: 255
    t.datetime "created_at",                                  null: false
    t.datetime "updated_at",                                  null: false
    t.string   "identifier",                    limit: 255
    t.boolean  "simple_button"
    t.integer  "display_index",                 limit: 4
    t.boolean  "disabled"
  end

  add_index "state_toggle_buttons", ["display_index"], name: "index_state_toggle_buttons_on_display_index", using: :btree
  add_index "state_toggle_buttons", ["identifier"], name: "index_state_toggle_buttons_on_identifier", unique: true, using: :btree
  add_index "state_toggle_buttons", ["module_type"], name: "index_state_toggle_buttons_on_module_type", using: :btree
  add_index "state_toggle_buttons", ["updated_at"], name: "index_state_toggle_buttons_on_updated_at", using: :btree

  create_table "status_rules", force: :cascade do |t|
    t.string   "module_type", limit: 255
    t.string   "name",        limit: 255
    t.string   "description", limit: 255
    t.integer  "test_rank",   limit: 4
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
  end

  create_table "stitch_queue_items", force: :cascade do |t|
    t.string   "stitch_type",          limit: 255
    t.string   "stitch_queuable_type", limit: 255
    t.integer  "stitch_queuable_id",   limit: 4
    t.datetime "created_at",                       null: false
    t.datetime "updated_at",                       null: false
  end

  add_index "stitch_queue_items", ["stitch_type", "stitch_queuable_type", "stitch_queuable_id"], name: "index_stitch_queue_item_by_types_and_id", unique: true, using: :btree

  create_table "summary_statements", force: :cascade do |t|
    t.string   "statement_number", limit: 255
    t.integer  "customer_id",      limit: 4,   null: false
    t.datetime "created_at",                   null: false
    t.datetime "updated_at",                   null: false
  end

  create_table "support_requests", force: :cascade do |t|
    t.string   "ticket_number", limit: 255
    t.text     "body",          limit: 65535
    t.string   "severity",      limit: 255
    t.string   "referrer_url",  limit: 255
    t.integer  "user_id",       limit: 4
    t.string   "external_link", limit: 255
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
  end

  add_index "support_requests", ["user_id"], name: "index_support_requests_on_user_id", using: :btree

  create_table "support_ticket_comments", force: :cascade do |t|
    t.integer  "support_ticket_id", limit: 4
    t.integer  "user_id",           limit: 4
    t.text     "body",              limit: 65535
    t.datetime "created_at",                      null: false
    t.datetime "updated_at",                      null: false
  end

  add_index "support_ticket_comments", ["support_ticket_id"], name: "index_support_ticket_comments_on_support_ticket_id", using: :btree

  create_table "support_tickets", force: :cascade do |t|
    t.integer  "requestor_id",        limit: 4
    t.integer  "agent_id",            limit: 4
    t.string   "subject",             limit: 255
    t.text     "body",                limit: 65535
    t.text     "state",               limit: 65535
    t.boolean  "email_notifications"
    t.integer  "last_saved_by_id",    limit: 4
    t.datetime "created_at",                        null: false
    t.datetime "updated_at",                        null: false
  end

  add_index "support_tickets", ["agent_id"], name: "index_support_tickets_on_agent_id", using: :btree
  add_index "support_tickets", ["requestor_id"], name: "index_support_tickets_on_requestor_id", using: :btree

  create_table "survey_response_logs", force: :cascade do |t|
    t.integer  "survey_response_id", limit: 4
    t.text     "message",            limit: 65535
    t.datetime "created_at",                       null: false
    t.datetime "updated_at",                       null: false
    t.integer  "user_id",            limit: 4
  end

  add_index "survey_response_logs", ["survey_response_id"], name: "index_survey_response_logs_on_survey_response_id", using: :btree
  add_index "survey_response_logs", ["user_id"], name: "index_survey_response_logs_on_user_id", using: :btree

  create_table "survey_response_updates", force: :cascade do |t|
    t.integer  "user_id",            limit: 4
    t.integer  "survey_response_id", limit: 4
    t.datetime "created_at",                   null: false
    t.datetime "updated_at",                   null: false
  end

  add_index "survey_response_updates", ["survey_response_id", "user_id"], name: "index_survey_response_updates_on_survey_response_id_and_user_id", unique: true, using: :btree
  add_index "survey_response_updates", ["user_id"], name: "index_survey_response_updates_on_user_id", using: :btree

  create_table "survey_responses", force: :cascade do |t|
    t.integer  "survey_id",                       limit: 4
    t.integer  "user_id",                         limit: 4
    t.datetime "email_sent_date"
    t.datetime "email_opened_date"
    t.datetime "response_opened_date"
    t.datetime "submitted_date"
    t.datetime "accepted_date"
    t.datetime "created_at",                                    null: false
    t.datetime "updated_at",                                    null: false
    t.string   "status",                          limit: 255
    t.string   "rating",                          limit: 255
    t.string   "name",                            limit: 255
    t.text     "address",                         limit: 65535
    t.string   "phone",                           limit: 255
    t.string   "fax",                             limit: 255
    t.string   "email",                           limit: 255
    t.string   "subtitle",                        limit: 255
    t.boolean  "archived"
    t.datetime "expiration_notification_sent_at"
    t.string   "base_object_type",                limit: 255
    t.integer  "base_object_id",                  limit: 4
    t.integer  "group_id",                        limit: 4
    t.integer  "checkout_by_user_id",             limit: 4
    t.string   "checkout_token",                  limit: 255
    t.datetime "checkout_expiration"
  end

  add_index "survey_responses", ["base_object_type", "base_object_id"], name: "index_survey_responses_on_base_object_type_and_base_object_id", using: :btree
  add_index "survey_responses", ["rating"], name: "index_survey_responses_on_rating", using: :btree
  add_index "survey_responses", ["survey_id"], name: "index_survey_responses_on_survey_id", using: :btree
  add_index "survey_responses", ["user_id"], name: "index_survey_responses_on_user_id", using: :btree

  create_table "survey_subscriptions", force: :cascade do |t|
    t.integer  "survey_id",  limit: 4
    t.integer  "user_id",    limit: 4
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
  end

  create_table "surveys", force: :cascade do |t|
    t.integer  "company_id",                  limit: 4
    t.integer  "created_by_id",               limit: 4
    t.string   "name",                        limit: 255
    t.string   "email_subject",               limit: 255
    t.text     "email_body",                  limit: 65535
    t.datetime "created_at",                                                null: false
    t.datetime "updated_at",                                                null: false
    t.text     "ratings_list",                limit: 65535
    t.integer  "expiration_days",             limit: 4
    t.boolean  "archived",                                  default: false
    t.string   "system_code",                 limit: 255
    t.integer  "trade_preference_program_id", limit: 4
    t.boolean  "require_contact"
  end

  add_index "surveys", ["company_id"], name: "index_surveys_on_company_id", using: :btree
  add_index "surveys", ["system_code"], name: "index_surveys_on_system_code", using: :btree
  add_index "surveys", ["trade_preference_program_id"], name: "tpp_id", using: :btree

  create_table "sync_records", force: :cascade do |t|
    t.integer  "syncable_id",            limit: 4
    t.string   "syncable_type",          limit: 255
    t.string   "trading_partner",        limit: 255
    t.datetime "sent_at"
    t.datetime "confirmed_at"
    t.string   "confirmation_file_name", limit: 255
    t.string   "failure_message",        limit: 255
    t.datetime "created_at",                           null: false
    t.datetime "updated_at",                           null: false
    t.string   "fingerprint",            limit: 255
    t.datetime "ignore_updates_before"
    t.integer  "ftp_session_id",         limit: 4
    t.text     "context",                limit: 65535
    t.integer  "api_session_id",         limit: 4
  end

  add_index "sync_records", ["api_session_id"], name: "index_sync_records_on_api_session_id", using: :btree
  add_index "sync_records", ["ftp_session_id"], name: "index_sync_records_on_ftp_session_id", using: :btree
  add_index "sync_records", ["syncable_id", "syncable_type", "trading_partner", "fingerprint"], name: "index_sync_records_id_type_trading_partner_fingerprint", unique: true, using: :btree
  add_index "sync_records", ["trading_partner"], name: "index_sync_records_on_trading_partner", using: :btree

  create_table "system_dates", force: :cascade do |t|
    t.string   "date_type",  limit: 255, null: false
    t.integer  "company_id", limit: 4
    t.datetime "start_date"
    t.datetime "end_date"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "system_dates", ["date_type", "company_id"], name: "index_system_dates_on_date_type_and_company_id", unique: true, using: :btree

  create_table "system_identifiers", force: :cascade do |t|
    t.integer  "company_id", limit: 4
    t.string   "system",     limit: 255, null: false
    t.string   "code",       limit: 255, null: false
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "system_identifiers", ["company_id", "system"], name: "index_system_identifiers_on_company_id_and_system", using: :btree
  add_index "system_identifiers", ["system", "code"], name: "index_system_identifiers_on_system_and_code", unique: true, using: :btree

  create_table "tariff_classification_rates", force: :cascade do |t|
    t.integer  "tariff_classification_id",  limit: 4
    t.string   "special_program_indicator", limit: 255
    t.decimal  "rate_specific",                         precision: 14, scale: 8
    t.decimal  "rate_advalorem",                        precision: 14, scale: 8
    t.decimal  "rate_additional",                       precision: 14, scale: 8
    t.datetime "created_at",                                                     null: false
    t.datetime "updated_at",                                                     null: false
  end

  add_index "tariff_classification_rates", ["tariff_classification_id", "special_program_indicator"], name: "idx_tariff_classification_rates_on_tariff_id_spi", using: :btree

  create_table "tariff_classifications", force: :cascade do |t|
    t.integer  "country_id",                limit: 4
    t.string   "tariff_number",             limit: 255
    t.date     "effective_date_start"
    t.date     "effective_date_end"
    t.decimal  "number_of_reporting_units",             precision: 10, scale: 2
    t.string   "unit_of_measure_1",         limit: 255
    t.string   "unit_of_measure_2",         limit: 255
    t.string   "unit_of_measure_3",         limit: 255
    t.string   "duty_computation",          limit: 255
    t.string   "base_rate_indicator",       limit: 255
    t.string   "tariff_description",        limit: 255
    t.boolean  "countervailing_duty"
    t.boolean  "antidumping_duty"
    t.boolean  "blocked_record"
    t.datetime "last_exported_from_source"
    t.datetime "created_at",                                                     null: false
    t.datetime "updated_at",                                                     null: false
  end

  add_index "tariff_classifications", ["tariff_number", "country_id", "effective_date_start"], name: "idx_tariff_classifications_on_number_country_effective_date", unique: true, using: :btree

  create_table "tariff_file_upload_definitions", force: :cascade do |t|
    t.string   "country_code",      limit: 255
    t.string   "filename_regex",    limit: 255
    t.string   "country_iso_alias", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "tariff_file_upload_definitions", ["country_code"], name: "idx_country_code", unique: true, using: :btree

  create_table "tariff_file_upload_instances", force: :cascade do |t|
    t.integer  "tariff_file_upload_definition_id", limit: 4
    t.string   "vfi_track_system_code",            limit: 255
    t.string   "country_iso_alias",                limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "tariff_file_upload_instances", ["tariff_file_upload_definition_id", "vfi_track_system_code"], name: "idx_definition_id_vfi_track_system_code", unique: true, using: :btree

  create_table "tariff_file_upload_receipts", force: :cascade do |t|
    t.integer  "tariff_file_upload_instance_id", limit: 4
    t.string   "filename",                       limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "tariff_records", force: :cascade do |t|
    t.string   "hts_1",             limit: 255
    t.string   "hts_2",             limit: 255
    t.string   "hts_3",             limit: 255
    t.integer  "classification_id", limit: 4
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
    t.integer  "line_number",       limit: 4
    t.string   "schedule_b_1",      limit: 255
    t.string   "schedule_b_2",      limit: 255
    t.string   "schedule_b_3",      limit: 255
  end

  add_index "tariff_records", ["classification_id"], name: "index_tariff_records_on_classification_id", using: :btree
  add_index "tariff_records", ["hts_1"], name: "index_tariff_records_on_hts_1", using: :btree
  add_index "tariff_records", ["hts_2"], name: "index_tariff_records_on_hts_2", using: :btree
  add_index "tariff_records", ["hts_3"], name: "index_tariff_records_on_hts_3", using: :btree

  create_table "tariff_set_records", force: :cascade do |t|
    t.integer  "tariff_set_id",                    limit: 4
    t.integer  "country_id",                       limit: 4
    t.string   "hts_code",                         limit: 255
    t.text     "full_description",                 limit: 65535
    t.text     "special_rates",                    limit: 65535
    t.string   "general_rate",                     limit: 255
    t.text     "chapter",                          limit: 65535
    t.text     "heading",                          limit: 65535
    t.text     "sub_heading",                      limit: 65535
    t.text     "remaining_description",            limit: 65535
    t.string   "add_valorem_rate",                 limit: 255
    t.string   "per_unit_rate",                    limit: 255
    t.string   "calculation_method",               limit: 255
    t.string   "most_favored_nation_rate",         limit: 255
    t.string   "general_preferential_tariff_rate", limit: 255
    t.string   "erga_omnes_rate",                  limit: 255
    t.string   "unit_of_measure",                  limit: 255
    t.text     "column_2_rate",                    limit: 65535
    t.string   "import_regulations",               limit: 255
    t.string   "export_regulations",               limit: 255
    t.datetime "created_at",                                     null: false
    t.datetime "updated_at",                                     null: false
    t.string   "fda_indicator",                    limit: 255
  end

  add_index "tariff_set_records", ["hts_code"], name: "index_tariff_set_records_on_hts_code", using: :btree
  add_index "tariff_set_records", ["tariff_set_id"], name: "index_tariff_set_records_on_tariff_set_id", using: :btree

  create_table "tariff_sets", force: :cascade do |t|
    t.integer  "country_id", limit: 4
    t.string   "label",      limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
    t.boolean  "active"
  end

  create_table "tpp_hts_overrides", force: :cascade do |t|
    t.integer  "trade_preference_program_id", limit: 4
    t.string   "hts_code",                    limit: 255
    t.decimal  "rate",                                      precision: 8, scale: 4
    t.text     "note",                        limit: 65535
    t.date     "start_date"
    t.date     "end_date"
    t.datetime "created_at",                                                        null: false
    t.datetime "updated_at",                                                        null: false
  end

  add_index "tpp_hts_overrides", ["hts_code"], name: "index_tpp_hts_overrides_on_hts_code", using: :btree
  add_index "tpp_hts_overrides", ["start_date", "end_date"], name: "active_dates", using: :btree
  add_index "tpp_hts_overrides", ["trade_preference_program_id"], name: "tpp_id", using: :btree

  create_table "trade_lanes", force: :cascade do |t|
    t.integer  "origin_country_id",            limit: 4
    t.integer  "destination_country_id",       limit: 4
    t.decimal  "tariff_adjustment_percentage",               precision: 5, scale: 2
    t.text     "notes",                        limit: 65535
    t.datetime "created_at",                                                         null: false
    t.datetime "updated_at",                                                         null: false
  end

  add_index "trade_lanes", ["destination_country_id"], name: "index_trade_lanes_on_destination_country_id", using: :btree
  add_index "trade_lanes", ["origin_country_id", "destination_country_id"], name: "unique_country_pair", unique: true, using: :btree
  add_index "trade_lanes", ["origin_country_id"], name: "index_trade_lanes_on_origin_country_id", using: :btree

  create_table "trade_preference_programs", force: :cascade do |t|
    t.string   "name",                         limit: 255
    t.integer  "origin_country_id",            limit: 4
    t.integer  "destination_country_id",       limit: 4
    t.string   "tariff_identifier",            limit: 255
    t.decimal  "tariff_adjustment_percentage",             precision: 5, scale: 2
    t.datetime "created_at",                                                       null: false
    t.datetime "updated_at",                                                       null: false
  end

  add_index "trade_preference_programs", ["destination_country_id"], name: "tpp_destination", using: :btree
  add_index "trade_preference_programs", ["origin_country_id"], name: "tpp_origin", using: :btree

  create_table "unit_of_measures", force: :cascade do |t|
    t.string   "uom",         limit: 255
    t.string   "description", limit: 255
    t.string   "system",      limit: 255
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
  end

  add_index "unit_of_measures", ["uom", "system"], name: "index_unit_of_measures_on_uom_and_system", using: :btree

  create_table "upgrade_logs", force: :cascade do |t|
    t.string   "from_version",            limit: 255
    t.string   "to_version",              limit: 255
    t.datetime "started_at"
    t.datetime "finished_at"
    t.text     "log",                     limit: 65535
    t.integer  "instance_information_id", limit: 4
    t.datetime "created_at",                            null: false
    t.datetime "updated_at",                            null: false
  end

  create_table "user_announcement_markers", force: :cascade do |t|
    t.integer  "user_id",         limit: 4
    t.integer  "announcement_id", limit: 4
    t.datetime "confirmed_at"
    t.boolean  "hidden"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "user_announcement_markers", ["user_id", "announcement_id"], name: "index_user_announcement_markers_on_user_id_and_announcement_id", using: :btree

  create_table "user_announcements", force: :cascade do |t|
    t.integer  "user_id",         limit: 4
    t.integer  "announcement_id", limit: 4
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "user_announcements", ["user_id", "announcement_id"], name: "index_user_announcements_on_user_id_and_announcement_id", using: :btree

  create_table "user_group_memberships", force: :cascade do |t|
    t.integer "group_id", limit: 4
    t.integer "user_id",  limit: 4
  end

  add_index "user_group_memberships", ["group_id"], name: "index_user_group_memberships_on_group_id", using: :btree
  add_index "user_group_memberships", ["user_id", "group_id"], name: "index_user_group_memberships_on_user_id_and_group_id", unique: true, using: :btree

  create_table "user_manuals", force: :cascade do |t|
    t.string   "name",                limit: 255
    t.string   "page_url_regex",      limit: 255
    t.text     "groups",              limit: 65535
    t.datetime "created_at",                                        null: false
    t.datetime "updated_at",                                        null: false
    t.string   "wistia_code",         limit: 255
    t.string   "category",            limit: 255
    t.boolean  "master_company_only",               default: false
    t.string   "document_url",        limit: 255
  end

  create_table "user_password_histories", force: :cascade do |t|
    t.integer  "user_id",         limit: 4
    t.string   "hashed_password", limit: 255
    t.string   "password_salt",   limit: 255
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
  end

  add_index "user_password_histories", ["user_id", "created_at"], name: "index_user_password_histories_on_user_id_and_created_at", using: :btree

  create_table "user_sessions", force: :cascade do |t|
    t.string   "username",   limit: 255
    t.string   "password",   limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  create_table "user_templates", force: :cascade do |t|
    t.string   "name",          limit: 255
    t.text     "template_json", limit: 65535
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
  end

  create_table "users", force: :cascade do |t|
    t.string   "username",                   limit: 255
    t.string   "email",                      limit: 255
    t.string   "crypted_password",           limit: 255
    t.string   "password_salt",              limit: 255
    t.string   "persistence_token",          limit: 255
    t.integer  "failed_login_count",         limit: 4,     default: 0,     null: false
    t.datetime "last_request_at"
    t.datetime "current_login_at"
    t.datetime "last_login_at"
    t.datetime "created_at",                                               null: false
    t.datetime "updated_at",                                               null: false
    t.boolean  "disabled"
    t.integer  "company_id",                 limit: 4
    t.string   "first_name",                 limit: 255
    t.string   "last_name",                  limit: 255
    t.string   "time_zone",                  limit: 255
    t.string   "email_format",               limit: 255
    t.boolean  "admin"
    t.boolean  "sys_admin"
    t.string   "perishable_token",           limit: 255,   default: "",    null: false
    t.datetime "debug_expires"
    t.boolean  "search_open"
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
    t.boolean  "email_new_messages",                       default: false
    t.string   "host_with_port",             limit: 255
    t.boolean  "entry_view"
    t.boolean  "broker_invoice_view"
    t.integer  "run_as_id",                  limit: 4
    t.boolean  "entry_comment"
    t.boolean  "entry_attach"
    t.boolean  "entry_edit"
    t.boolean  "survey_view"
    t.boolean  "survey_edit"
    t.boolean  "commercial_invoice_view"
    t.boolean  "commercial_invoice_edit"
    t.boolean  "support_agent"
    t.boolean  "password_reset"
    t.boolean  "broker_invoice_edit"
    t.boolean  "drawback_view"
    t.boolean  "drawback_edit"
    t.boolean  "simple_entry_mode"
    t.boolean  "security_filing_view"
    t.boolean  "security_filing_edit"
    t.boolean  "security_filing_attach"
    t.boolean  "security_filing_comment"
    t.text     "hidden_message_json",        limit: 65535
    t.boolean  "tariff_subscribed"
    t.string   "api_auth_token",             limit: 255
    t.integer  "api_request_counter",        limit: 4
    t.boolean  "project_view"
    t.boolean  "project_edit"
    t.string   "homepage",                   limit: 255
    t.string   "encrypted_password",         limit: 128
    t.string   "confirmation_token",         limit: 128
    t.string   "remember_token",             limit: 128
    t.string   "provider",                   limit: 255
    t.string   "uid",                        limit: 255
    t.string   "google_name",                limit: 255
    t.string   "oauth_token",                limit: 255
    t.datetime "oauth_expires_at"
    t.boolean  "disallow_password"
    t.boolean  "vendor_view"
    t.boolean  "vendor_edit"
    t.boolean  "vendor_attach"
    t.boolean  "vendor_comment"
    t.boolean  "task_email"
    t.boolean  "variant_edit"
    t.string   "portal_mode",                limit: 255
    t.string   "User",                       limit: 255
    t.boolean  "trade_lane_view"
    t.boolean  "trade_lane_edit"
    t.boolean  "trade_lane_attach"
    t.boolean  "trade_lane_comment"
    t.boolean  "vfi_invoice_edit"
    t.boolean  "vfi_invoice_view"
    t.boolean  "system_user"
    t.datetime "password_changed_at"
    t.integer  "failed_logins",              limit: 4,     default: 0
    t.boolean  "password_locked",                          default: false
    t.boolean  "password_expired",                         default: false
    t.boolean  "forgot_password"
    t.boolean  "statement_view"
    t.string   "department",                 limit: 255
    t.integer  "active_days",                limit: 4,     default: 0
    t.string   "default_report_date_format", limit: 255
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
  add_index "users", ["remember_token"], name: "index_users_on_remember_token", using: :btree
  add_index "users", ["username"], name: "index_users_on_username", using: :btree

  create_table "variants", force: :cascade do |t|
    t.integer  "product_id",         limit: 4,   null: false
    t.string   "variant_identifier", limit: 255
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
  end

  add_index "variants", ["product_id"], name: "index_variants_on_product_id", using: :btree

  create_table "vfi_invoice_lines", force: :cascade do |t|
    t.integer  "vfi_invoice_id",     limit: 4,                            null: false
    t.integer  "line_number",        limit: 4
    t.string   "charge_description", limit: 255
    t.decimal  "charge_amount",                  precision: 11, scale: 2
    t.string   "charge_code",        limit: 255
    t.decimal  "quantity",                       precision: 11, scale: 2
    t.string   "unit",               limit: 255
    t.decimal  "unit_price",                     precision: 11, scale: 2
    t.datetime "created_at",                                              null: false
    t.datetime "updated_at",                                              null: false
  end

  add_index "vfi_invoice_lines", ["vfi_invoice_id"], name: "index_vfi_invoice_lines_on_vfi_invoice_id", using: :btree

  create_table "vfi_invoices", force: :cascade do |t|
    t.integer  "customer_id",    limit: 4,   null: false
    t.date     "invoice_date"
    t.string   "invoice_number", limit: 255
    t.string   "currency",       limit: 255
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
  end

  add_index "vfi_invoices", ["customer_id", "invoice_number"], name: "index_vfi_invoices_on_customer_id_and_invoice_number", unique: true, using: :btree

  create_table "worksheet_config_mappings", force: :cascade do |t|
    t.integer  "row",                  limit: 4
    t.integer  "column",               limit: 4
    t.string   "model_field_uid",      limit: 255
    t.integer  "custom_definition_id", limit: 4
    t.integer  "worksheet_config_id",  limit: 4
    t.datetime "created_at",                       null: false
    t.datetime "updated_at",                       null: false
  end

  create_table "worksheet_configs", force: :cascade do |t|
    t.string   "name",        limit: 255
    t.string   "module_type", limit: 255
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
  end

end
