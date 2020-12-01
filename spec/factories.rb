FactoryBot.define do
  sequence :iso do
    # Create fake ISO Codes starting w/ numbers so they won't collide w/ real ones
    # Sequence goes 0A, 0B, 0C...0Z, 1A, etc
    @first_counter ||= -1
    @second_counter ||= -1

    mod = (@second_counter += 1) % 26
    @first_counter += 1 if mod == 0
    # Reset the counter if it goes over 9 (otherwise we end up getting 00A, 00B, which ends up causing problems because mysql truncates them to 00, 00 - causing duplicate
    # key errors)
    @first_counter = 0 if @first_counter > 9

    "#{@first_counter}#{(65 + mod).chr}"
  end

  sequence :alpha_numeric do |n|
    "ALPHA#{n}"
  end

  factory :company do
    sequence(:name) { |n| "cname#{n}"}
  end

  factory :importer, class: Company do
    importer { true }
  end

  factory :consignee, class: Company do
    consignee { true }
  end

  factory :vendor, class: Company do
    vendor { true }
  end

  factory :factory, class: Company do
    add_attribute(:factory) { true }
  end

  factory :master_company, class: Company do
    master { true }
  end

  factory :broker, class: Company do
    broker { true }
  end

  factory :part_number_correlation do
  end

  factory :address do
    name  { "MYaddr" }
    country
    company
  end

  factory :full_address, class: Address do
    line_1 { '99 Fake Street' }
    city { 'Fakesville' }
    state { 'PA' }
    postal_code { '19191' }
  end

  factory :blank_address, class: Address do
    :company
  end

end
FactoryBot.define :project_update do |f|
  f.association :project
end
FactoryBot.define :project_deliverable do |f|
  f.association :project
end
FactoryBot.define :project_set do |f|
  f.sequence :name
end
FactoryBot.define :business_validation_template do |f|
  f.module_type 'Entry'
end
FactoryBot.define :business_validation_rule do |f|
  f.association :business_validation_template
  f.sequence :name
  f.sequence :description
end
FactoryBot.define :business_validation_result do |f|
  f.association :business_validation_template
end
FactoryBot.define :business_validation_rule_result do |f|
  f.association :business_validation_rule
  f.after_create {|rr|
    bvt = rr.business_validation_rule.business_validation_template
    rr.business_validation_result = bvt.business_validation_results.create!
    rr.save!
  }
end
FactoryBot.define :business_validation_rule_result_without_callback, class: BusinessValidationRuleResult do |c|
end
FactoryBot.define :container do |f|
  f.container_number {FactoryBot.next :alpha_numeric}
  f.association :entry
end

Factory.define :bill_of_lading do |f|
end

Factory.define :master_bill_of_lading, parent: :bill_of_lading do |f|
  f.bill_type "master"
end

Factory.define :house_bill_of_lading, parent: :bill_of_lading do |f|
  f.bill_type "house"
end

Factory.define :event_subscription do |f|
  f.association :user
  f.event_type 'ORDER_COMMENT_CREATE'
end
FactoryBot.define :email, class: OpenStruct do |f|
  # Assumes Griddler.configure.to is :hash (default)
  f.to [{ full: 'to_user@email.com', email: 'to_user@email.com', token: 'to_user', host: 'email.com', name: nil }]
  f.from 'user@email.com'
  f.subject 'email subject'
  f.body 'Hello!'
  f.attachments {[]}
end

  factory :master_user, class: User do
    association :company, factory: :master_company
  end

  factory :admin_user, :parent=>:master_user do
    after_create do |f|
      f.admin = true
      save!
    end
  end

  factory :sys_admin_user, :parent=>:master_user do
    after_create do |u|
      u.admin = true
      u.sys_admin = true
      u.save!
    end
  end

  factory :broker_user, class: User do
    entry_view { true }
    broker_invoice_view { true }
    after_create { |u| u.company.update_attributes(:broker=>true) }
  end

  factory :importer_user, class: User do
    entry_view { true }
    broker_invoice_view { true }
    after_create { |u| u.company.update_attributes(:importer=>true) }
  end

  factory :vendor_user, class: User do
    after_create { |u| u.company.update_attributes(:vendor=>true) }
  end

  factory :drawback_user, class: User do
    drawback_view { true }
    drawback_edit { true }
    after_create { |u| u.company.update_attributes(:drawback=>true) }
  end

  factory :user_template do
    name { 'mytemplate' }
    template_json { "{}" }
  end

  factory :country do
    iso_code { FactoryBot.next :iso }
    sequence(:name) {|n| "Country #{n}"}
  end

  factory :region do
  end

  factory :official_tariff do
    sequence(:hts_code) {|n| "123456#{n}"}
    full_description { "description" }
    country
  end

  factory :official_tariff_meta_datum do
    sequence(:hts_code) {|n| "123456#{n}"}
    association :country
  end

  factory :product do
    sequence(:unique_identifier) {|n| "uid#{n}"}
  end

  factory :classification do
    product
    country
  end

  factory :tariff_record do
    classification
  end

  factory :tariff_set do
    country
  end

  factory :product_group do
    sequence(:name)
  end

  factory :variant do
    sequence(:variant_identifier)
    product
  end

  factory :plant_variant_assignment do
    variant
    plant
  end

  factory :change_record do
    file_import_result
  end

  factory :change_record_message do
    change_record
  end

  factory :linkable_attachment do
    model_field_uid { 'mfuid' }
    value { 'val' }
  end

  factory :linked_attachment do
    linkable_attachment
    after_build do |la|
      la.attachable = FactoryBot(:product)
    end
  end

  factory :order do
    sequence(:order_number)
    association :vendor, factory: :company
  end

  factory :order_line do
    product
    quantity { 1 }
    sequence(:line_number)
    order
  end

  factory :shipment do
    sequence(:reference, 'a')
    association :vendor, factory: :company
  end

  factory :shipment_line do
    sequence(:line_number)
    quantity { 1 }
    product
    shipment
  end

  factory :booking_line do
    sequence(:line_number)
    quantity { 1 }
    shipment
  end

  factory :piece_set do
  end

  factory :carton_set do
    sequence(:starting_carton)
    shipment
  end

  factory :sales_order do
    sequence(:order_number)
    association :customer, :factory => :company
  end

  factory :sales_order_line do
    sequence(:line_number)
    quantity { 1 }
    product
    sales_order
  end

  factory :delivery do
    sequence(:reference)
    association :customer, :factory => :company
  end

  factory :delivery_line do
    sequence(:line_number)
    quantity { 1 }
    product
    delivery
  end

  factory :drawback_import_line do
    sequence :line_number
    quantity { 1 }
    product
  end

  factory :linkable_attachment_import_rule do
    sequence(:path)
    model_field_uid { 'mfuid' }
  end

  factory :search_setup do
    name { 'search name' }
    module_type { 'Product' }
    user
  end

  factory :custom_report do
    name { 'custom report name' }
    user
  end

  factory :calendar do
    calendar_type { 'xyz' }
    year { 2099 }
    company_id { nil }
  end

  factory :calendar_event do
    label { '' }
    event_date { '2019-04-05' }
    calendar
  end

  factory :search_schedule do
    search_setup
    log_runtime { false }
  end

  factory :search_criterion do
    model_field_uid { 'prod_uid' }
    operator { 'eq' }
    value { 'x' }
  end

  factory :sort_criterion do
    model_field_uid { 'prod_uid' }
  end

  factory :search_column do
    model_field_uid { 'prod_uid' }
  end

  factory :search_template do
    name { 'search_name' }
    search_json { '{"name":"search_name","module_type":"Order","include_links":true,"include_rule_links":true,no_time":true}' }
  end

  factory :custom_definition do
    sequence(:label)
    data_type { "string" }
    module_type { "Product" }
  end

  factory :imported_file do
    module_type { "Product" }
    starting_row  { 1 }
    starting_column { 1 }
    update_mode { "any" }
  end

  factory :file_import_result do
    imported_file
    association :run_by, :factory => :user
  end

  factory :custom_file do
  end

  factory :power_of_attorney do
    user
    company
    start_date { "2011-12-01" }
    expiration_date { "2011-12-31" }
    attachment_file_name { "SpecAttachmentDocument.odt" }
  end

  factory :entry do
  end

  factory :commercial_invoice do
    entry
  end

  factory :commercial_invoice_line do
    commercial_invoice
    sequence :line_number
  end

  factory :commercial_invoice_tariff do
    commercial_invoice_line
  end

  factory :canadian_pga_line do
    commercial_invoice_line
  end

  factory :canadian_pga_line_ingredient do
    canadian_pga_line
  end

  factory :invoice do
  end

  factory :invoice_line do
    invoice
    sequence :line_number
  end

  factory :broker_invoice do
    sequence :invoice_number
    entry
  end

  factory :broker_invoice_line do
    broker_invoice
    charge_description { FactoryBot.next :alpha_numeric }
    charge_code { FactoryBot.next :alpha_numeric }
    charge_amount { 1 }
  end

  factory :port do
    schedule_k_code { '23456' }
    schedule_d_code { '1424' }
    name { 'abc def' }
  end

  factory :message do
    add_attribute(:subject) { 'ABC' }
    body { 'DEF' }
    user
  end

  factory :attachment do
    attached_file_name { "foo.bar" }
    attached_content_type { "image/png" }
  end

  factory :email_attachment do
    email { "ea@example.com" }
    after_create do |ea|
      ea.attachment = FactoryBot(:attachment, attachable: ea)
      ea.save
    end
  end

  factory :survey do
    company
    association :created_by, factory: :user
  end

  factory :question do
    survey
    content { "My question content" }
  end

  factory :survey_response do
    user
    survey
    name { 'joe smith' }
    address { 'xyz' }
    phone { '1234567890' }
    fax { '1234567890' }
    email { 'a@b.com' }
  end

  factory :corrective_action_plan do
    survey_response
  end

  factory :answer do
    question
    survey_response
  end

  factory :commercial_invoice_map do
    source_mfid { "prod_uid" }
    destination_mfid { "cil_part_number" }
  end

  factory :support_ticket do
    association :requestor, :factory => :user
    add_attribute(:subject) { "at least 10 characters" }
  end

  factory :support_request do
    user
  end

  factory :survey_subscription do
    survey
    user
  end

  factory :ftp_session do
    username { "foo" }
    add_attribute(:server) { "foo.example.com" }
    file_name { "bar.txt" }
    log { "test log" }
    data { "sample data" }
  end

  factory :api_session do
  end

  factory :duty_calc_export_file_line do
  end

  factory :duty_calc_import_file do
    association :importer, :factory => :company
  end

  factory :duty_calc_export_file do
    association :importer, :factory => :company
  end

  factory :charge_code do |f|
    f.sequence :code
    f.description "cc description"
  end
  factory :drawback_claim do |f|
    f.name "dname"
    f.association :importer, :factory => :company
  end
  factory :security_filing do |f|
    f.association :importer, :factory => :company
  end
  factory :schedulable_job do |f|
    f.log_runtime false
  end
  factory :project do |f|

  end
  factory :project_update do |f|
    f.association :project
  end
  factory :project_deliverable do |f|
    f.association :project
  end
  factory :project_set do |f|
    f.sequence :name
  end
  factory :business_validation_template do |f|
    f.module_type 'Entry'
  end
  factory :business_validation_rule do |f|
    f.association :business_validation_template
    f.sequence :name
    f.sequence :description
  end
  factory :business_validation_result do |f|
    f.association :business_validation_template
  end
  factory :business_validation_rule_result do |f|
    f.association :business_validation_rule
    f.after_create {|rr|
      bvt = rr.business_validation_rule.business_validation_template
      rr.business_validation_result = bvt.business_validation_results.create!
      rr.save!
    }
  end
  factory :business_validation_rule_result_without_callback, class: BusinessValidationRuleResult do |c|
  end
  factory :container do |f|
    f.container_number {FactoryBot.next :alpha_numeric}
    f.association :entry
  end
  factory :event_subscription do |f|
    f.association :user
    f.event_type 'ORDER_COMMENT_CREATE'
  end
  factory :email, class: OpenStruct do |f|
    # Assumes Griddler.configure.to is :hash (default)
    f.to [{ full: 'to_user@email.com', email: 'to_user@email.com', token: 'to_user', host: 'email.com', name: nil }]
    f.from 'user@email.com'
    f.subject 'email subject'
    f.body 'Hello!'
    f.attachments {[]}
  end

  factory :group do |f|
    f.sequence(:system_code) {|c| "code#{c}"}
    f.name "Group Name"
  end

  factory :mailing_list do |f|
    f.sequence(:system_code) { |c| "code#{c}"}
    f.name "Mailing List Name"
    f.association :user
    f.association :company
  end

  factory :state_toggle_button do |f|

  end

  factory :plant do |f|
    f.sequence(:name) { |n| "pname#{n}"}
    f.association :company
  end
  factory :plant_product_group_assignment do |f|
    f.association :plant
    f.association :product_group
  end

  factory :sent_email do |f|
    f.sequence(:email_subject) { |n| "subject#{n}" }
    f.sequence(:email_to) { |n| "recipient#{n}" }
    f.sequence(:email_from) { |n| "sender#{n}" }
  end

  factory :summary_statement do |f|
    f.sequence(:statement_number) { |n| "statement_#{n}" }
    f.association :customer, :factory => :company
  end

  factory :user_manual do |f|
    f.name "MyManual"
  end

  factory :product_vendor_assignment do |f|
    f.association :product
    f.association :vendor
  end

  factory :custom_view_template do |f|
    f.module_type "Entry"
    f.sequence(:template_identifier) {|n| "template_identifier_#{n}"}
    f.sequence(:template_path) {|n| "/path/to/template_#{n}"}
  end

  factory :bulk_process_log do |f|
    f.association :user
  end
  factory :trade_lane do |f|
    f.association :origin_country, factory: :country
    f.association :destination_country, factory: :country
  end

  factory :trade_preference_program do |f|
    f.name 'TPP'
    f.association :origin_country, factory: :country
    f.association :destination_country, factory: :country
  end

  factory :tpp_hts_override do |f|
    f.association :trade_preference_program
    f.hts_code '1234567890'
    f.start_date Date.new(1900, 1, 1)
    f.end_date Date.new(2999, 12, 31)
  end

  factory :product_trade_preference_program do |f|
    f.association :product
    f.association :trade_preference_program
  end

  factory :spi_rate do |f|
    f.association :country
    f.special_rate_key 'ABC'
    f.rate_text 'SOMETEXT'
  end

  factory :product_rate_override do |f|
    f.association :product
    f.start_date Date.new(1900, 1, 1)
    f.end_date Date.new(2999, 12, 31)
  end

  factory :entity_snapshot do |f|
    f.association :recordable, :factory => :entry
    f.association :user
  end

  factory :billable_event do |f|
    f.association :billable_eventable, :factory => :entry
    f.association :entity_snapshot
  end

  factory :invoiced_event do |f|
    f.association :billable_event
  end

  factory :non_invoiced_event do |f|
    f.association :billable_event
  end

  factory :vfi_invoice do |f|
    f.association :customer, :factory=>:company
    f.sequence :invoice_number
  end

  factory :vfi_invoice_line do |f|
    f.association :vfi_invoice
    f.sequence :line_number
    f.charge_description {FactoryBot.next :alpha_numeric}
    f.unit_price 5
    f.quantity 1
    f.charge_amount 1
  end
  factory :search_table_config do |f|
    f.name 'stc'
    f.sequence :page_uid
  end

  factory :folder do |f|
    f.base_object :order
    f.created_by :user
  end
  factory :aws_backup_session do |f|
  end
  factory :aws_snapshot do |f|
    f.association :aws_backup_session
  end
  factory :fiscal_month do |f|
    f.association :company
  end
  factory :attachment_archive_setup do |f|
    f.association :company
    f.output_path ''
  end
  factory :random_audit do |f|
    f.association :user
    f.association :search_setup
  end

  factory :business_validation_scheduled_job do |f|
    f.validatable :entry
  end
  factory :business_validation_schedule do |f|
    f.name 'schedule'
    f.module_type "Entry"
  end

  factory :one_time_alert do |f|
    f.association :user
  end
  factory :one_time_alert_log_entry do |f|
    f.association :one_time_alert
  end

  factory :tariff_classification do |f|
    f.association :country
  end
  factory :tariff_classification_rate do |f|
    f.association :tariff_classification
  end
  factory :monthly_statement do |f|
  end
  factory :daily_statement do |f|
    f.association :monthly_statement
  end
  factory :daily_statement_entry do |f|
    f.association :daily_statement
  end
  factory :unit_of_measure do |f|
    f.uom 'foo'
    f.description 'bar'
    f.system 'Customs Management'
  end
  factory :announcement do |f|
    f.title 'title'
    f.start_at DateTime.new(2020, 3, 15, 12, 0)
    f.end_at DateTime.new(2020, 3, 20, 15, 0)
  end
  factory :user_announcement do |f|
  end
  factory :user_announcement_marker do |f|
  end

  factory :runtime_log do |l|
  end

  factory :inbound_file do |file|
  end
end
