FactoryBot.sequence :iso do |n|
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
FactoryBot.sequence :alpha_numeric do |n|
  "ALPHA#{n}"
end
FactoryBot.define :company do |c|
  c.sequence(:name) { |n| "cname#{n}"}
end
FactoryBot.define :importer, parent: :company do |c|
  c.importer true
end
FactoryBot.define :consignee, parent: :company do |c|
  c.consignee true
end
FactoryBot.define :vendor, parent: :company do |c|
  c.vendor true
end
FactoryBot.define :factory, parent: :company do |c|
  c.factory true
end
FactoryBot.define :master_company, parent: :company do |c|
  c.master true
end
FactoryBot.define :broker, parent: :company do |c|
  c.broker true
end
FactoryBot.define :part_number_correlation do |c|
end
FactoryBot.define :address do |a|
  a.name "MYaddr"
  a.association :country
  a.association :company
end
FactoryBot.define :full_address, parent: :address do |a|
  a.line_1 '99 Fake Street'
  a.city 'Fakesville'
  a.state 'PA'
  a.postal_code '19191'
end
FactoryBot.define :blank_address, class: Address do |a|
  a.association :company
end
FactoryBot.define :user do |f|
  f.sequence(:username) { |n| "foo#{n}" }
  f.password "foobar"
  f.sequence(:email) { |n| "foo#{n}@example.com" }
  f.association :company
  f.api_auth_token "auth_token"
end
FactoryBot.define :master_user, :parent=>:user do |f|
  f.association :company, :factory => :master_company
end
FactoryBot.define :admin_user, :parent=>:master_user do |f|
  f.after_create do |u|
    u.admin = true
    u.save!
  end
end
FactoryBot.define :sys_admin_user, :parent=>:master_user do |f|
  f.after_create do |u|
    u.admin = true
    u.sys_admin = true
    u.save!
  end
end
FactoryBot.define :broker_user, :parent=>:user do |f|
  f.entry_view true
  f.broker_invoice_view true
  f.after_create {|u| u.company.update_attributes(:broker=>true)}
end
FactoryBot.define :importer_user, :parent=>:user do |f|
  f.entry_view true
  f.broker_invoice_view true
  f.after_create {|u| u.company.update_attributes(:importer=>true)}
end
FactoryBot.define :vendor_user, :parent=>:user do |f|
  f.after_create {|u| u.company.update_attributes(:vendor=>true)}
end
FactoryBot.define :drawback_user, :parent=>:user do |f|
  f.drawback_view true
  f.drawback_edit true
  f.after_create {|u| u.company.update_attributes(:drawback=>true)}
end
FactoryBot.define :user_template do |f|
  f.name 'mytemplate'
  f.template_json "{}"
end
FactoryBot.define :country do |c|
  c.iso_code {FactoryBot.next :iso}
  c.sequence(:name) {|n| "Country #{n}"}
end
FactoryBot.define :region do |f|
end
FactoryBot.define :official_tariff do |t|
  t.sequence(:hts_code) {|n| "123456#{n}"}
  t.full_description "description"
  t.association :country
end
FactoryBot.define :official_tariff_meta_datum do |t|
  t.sequence(:hts_code) {|n| "123456#{n}"}
  t.association :country
end
FactoryBot.define :product do |p|
  p.sequence(:unique_identifier) {|n| "uid#{n}"}
end
FactoryBot.define :classification do |c|
  c.association :product
  c.association :country
end
FactoryBot.define :tariff_record do |t|
  t.association :classification
end
FactoryBot.define :tariff_set do |t|
  t.association :country
end
FactoryBot.define :product_group do |f|
  f.sequence(:name)
end
FactoryBot.define :variant do |f|
  f.sequence(:variant_identifier)
  f.association :product
end
FactoryBot.define :plant_variant_assignment do |f|
  f.association :variant
  f.association :plant
end
FactoryBot.define :change_record do |t|
  t.association :file_import_result
end
FactoryBot.define :change_record_message do |t|
  t.association :change_record
end
FactoryBot.define :linkable_attachment do |t|
  t.model_field_uid 'mfuid'
  t.value 'val'
end
FactoryBot.define :linked_attachment do |t|
  t.association :linkable_attachment
  t.after_build do |la|
    la.attachable = FactoryBot(:product)
  end
end
FactoryBot.define :order do |o|
  o.sequence(:order_number)
  o.association :vendor, :factory => :company
end
FactoryBot.define :order_line do |o|
  o.association :product
  o.quantity 1
  o.sequence(:line_number)
  o.association :order
end
FactoryBot.define :shipment do |s|
  s.sequence(:reference, 'a')
  s.association :vendor, :factory => :company
end
FactoryBot.define :shipment_line do |s|
  s.sequence(:line_number)
  s.quantity 1
  s.association :product
  s.association :shipment
end
FactoryBot.define :booking_line do |s|
  s.sequence(:line_number)
  s.quantity 1
  s.association :shipment
end
FactoryBot.define :piece_set do |s|
end
FactoryBot.define :carton_set do |f|
  f.sequence(:starting_carton)
  f.association :shipment
end
FactoryBot.define :sales_order do |s|
  s.sequence(:order_number)
  s.association :customer, :factory => :company
end
FactoryBot.define :sales_order_line do |s|
  s.sequence(:line_number)
  s.quantity 1
  s.association :product
  s.association :sales_order
end
FactoryBot.define :delivery do |d|
  d.sequence(:reference)
  d.association :customer, :factory => :company
end
FactoryBot.define :delivery_line do |d|
  d.sequence(:line_number)
  d.quantity 1
  d.association :product
  d.association :delivery
end
FactoryBot.define :drawback_import_line do |d|
  d.sequence :line_number
  d.quantity 1
  d.association :product
end
FactoryBot.define :linkable_attachment_import_rule do |a|
  a.sequence(:path)
  a.model_field_uid 'mfuid'
end
FactoryBot.define :search_setup do |s|
  s.name  'search name'
  s.module_type  'Product'
  s.association :user
end
FactoryBot.define :custom_report do |s|
  s.name  'custom report name'
  s.association :user
end

FactoryBot.define :calendar do |c|
  c.calendar_type 'xyz'
  c.year 2099
  c.company_id nil
end

FactoryBot.define :calendar_event do |e|
  e.label ''
  e.event_date '2019-04-05'
  e.association :calendar
end

FactoryBot.define :search_schedule do |s|
  s.association :search_setup
  s.log_runtime false
end
FactoryBot.define :search_criterion do |f|
  f.model_field_uid 'prod_uid'
  f.operator 'eq'
  f.value 'x'
end
FactoryBot.define :sort_criterion do |f|
  f.model_field_uid 'prod_uid'
end
FactoryBot.define :search_column do |f|
  f.model_field_uid 'prod_uid'
end
FactoryBot.define :search_template do |f|
  f.name 'search_name'
  # {name:ss.name,
  #     module_type:ss.module_type,
  #     include_links:ss.include_links,
  #     no_time:ss.no_time
  #   }
  f.search_json '{"name":"search_name","module_type":"Order","include_links":true,"include_rule_links":true,no_time":true}'
end
FactoryBot.define :custom_definition do |c|
  c.sequence(:label)
  c.data_type "string"
  c.module_type "Product"
end
FactoryBot.define :imported_file do |f|
  f.module_type "Product"
  f.starting_row  1
  f.starting_column  1
  f.update_mode "any"
end
FactoryBot.define :file_import_result do |f|
  f.association :imported_file
  f.association :run_by, :factory => :user
end
FactoryBot.define :custom_file do |f|
end
FactoryBot.define :power_of_attorney do |poa|
  poa.association :user
  poa.association :company
  poa.start_date "2011-12-01"
  poa.expiration_date "2011-12-31"
  poa.attachment_file_name "SpecAttachmentDocument.odt"
end
FactoryBot.define :entry do |f|

end
FactoryBot.define :commercial_invoice do |f|
  f.association :entry
end
FactoryBot.define :commercial_invoice_line do |f|
  f.association :commercial_invoice
  f.sequence :line_number
end
FactoryBot.define :commercial_invoice_tariff do |f|
  f.association :commercial_invoice_line
end

FactoryBot.define :canadian_pga_line do |f|
  f.association :commercial_invoice_line
end

FactoryBot.define :canadian_pga_line_ingredient do |f|
  f.association :canadian_pga_line
end

FactoryBot.define :invoice do |f|

end
FactoryBot.define :invoice_line do |f|
  f.association :invoice
  f.sequence :line_number
end
FactoryBot.define :broker_invoice do |f|
  f.sequence :invoice_number
  f.association :entry
end
FactoryBot.define :broker_invoice_line do |f|
  f.association :broker_invoice
  f.charge_description {FactoryBot.next :alpha_numeric}
  f.charge_code {FactoryBot.next :alpha_numeric}
  f.charge_amount 1
end
FactoryBot.define :port do |f|
  f.schedule_k_code '23456'
  f.schedule_d_code '1424'
  f.name 'abc def'
end
FactoryBot.define :message do |f|
  f.subject 'ABC'
  f.body 'DEF'
  f.association :user
end
FactoryBot.define :attachment do |f|
  f.attached_file_name "foo.bar"
  f.attached_content_type "image/png"
end
FactoryBot.define :email_attachment do |f|
  f.email "ea@example.com"
  f.after_create { |ea| ea.attachment = FactoryBot(:attachment, :attachable => ea); ea.save }
end
FactoryBot.define :survey do |f|
  f.association :company
  f.association :created_by, :factory=>:user
end
FactoryBot.define :question do |f|
  f.association :survey
  f.content "My question content"
end
FactoryBot.define :survey_response do |f|
  f.association :user
  f.association :survey
  f.name 'joe smith'
  f.address 'xyz'
  f.phone '1234567890'
  f.fax '1234567890'
  f.email 'a@b.com'
end
FactoryBot.define :corrective_action_plan do |f|
  f.association :survey_response
end
FactoryBot.define :answer do |f|
  f.association :question
  f.association :survey_response
end
FactoryBot.define :commercial_invoice_map do |f|
  f.source_mfid "prod_uid"
  f.destination_mfid "cil_part_number"
end
FactoryBot.define :support_ticket do |f|
  f.association :requestor, :factory => :user
  f.subject "at least 10 characters"
end
FactoryBot.define :support_request do |f|
  f.association :user
end
FactoryBot.define :survey_subscription do |f|
  f.association :survey
  f.association :user
end
FactoryBot.define :ftp_session do |f|
  f.username "foo"
  f.server "foo.example.com"
  f.file_name "bar.txt"
  f.log "test log"
  f.data "sample data"
end
FactoryBot.define :api_session do |f|

end
FactoryBot.define :duty_calc_export_file_line do |f|

end
FactoryBot.define :duty_calc_import_file do |f|
  f.association :importer, :factory => :company
end
FactoryBot.define :duty_calc_export_file do |f|
  f.association :importer, :factory => :company
end
FactoryBot.define :charge_code do |f|
  f.sequence :code
  f.description "cc description"
end
FactoryBot.define :drawback_claim do |f|
  f.name "dname"
  f.association :importer, :factory => :company
end
FactoryBot.define :security_filing do |f|
  f.association :importer, :factory => :company
end
FactoryBot.define :schedulable_job do |f|
  f.log_runtime false
end
FactoryBot.define :project do |f|

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

FactoryBot.define :group do |f|
  f.sequence(:system_code) {|c| "code#{c}"}
  f.name "Group Name"
end

FactoryBot.define :mailing_list do |f|
  f.sequence(:system_code) { |c| "code#{c}"}
  f.name "Mailing List Name"
  f.association :user
  f.association :company
end

FactoryBot.define :state_toggle_button do |f|

end

FactoryBot.define :plant do |f|
  f.sequence(:name) { |n| "pname#{n}"}
  f.association :company
end
FactoryBot.define :plant_product_group_assignment do |f|
  f.association :plant
  f.association :product_group
end

FactoryBot.define :sent_email do |f|
  f.sequence(:email_subject) { |n| "subject#{n}" }
  f.sequence(:email_to) { |n| "recipient#{n}" }
  f.sequence(:email_from) { |n| "sender#{n}" }
end

FactoryBot.define :summary_statement do |f|
  f.sequence(:statement_number) { |n| "statement_#{n}" }
  f.association :customer, :factory => :company
end

FactoryBot.define :user_manual do |f|
  f.name "MyManual"
end

FactoryBot.define :product_vendor_assignment do |f|
  f.association :product
  f.association :vendor
end

FactoryBot.define :custom_view_template do |f|
  f.module_type "Entry"
  f.sequence(:template_identifier) {|n| "template_identifier_#{n}"}
  f.sequence(:template_path) {|n| "/path/to/template_#{n}"}
end

FactoryBot.define :bulk_process_log do |f|
  f.association :user
end
FactoryBot.define :trade_lane do |f|
  f.association :origin_country, factory: :country
  f.association :destination_country, factory: :country
end

FactoryBot.define :trade_preference_program do |f|
  f.name 'TPP'
  f.association :origin_country, factory: :country
  f.association :destination_country, factory: :country
end

FactoryBot.define :tpp_hts_override do |f|
  f.association :trade_preference_program
  f.hts_code '1234567890'
  f.start_date Date.new(1900, 1, 1)
  f.end_date Date.new(2999, 12, 31)
end

FactoryBot.define :product_trade_preference_program do |f|
  f.association :product
  f.association :trade_preference_program
end

FactoryBot.define :spi_rate do |f|
  f.association :country
  f.special_rate_key 'ABC'
  f.rate_text 'SOMETEXT'
end

FactoryBot.define :product_rate_override do |f|
  f.association :product
  f.start_date Date.new(1900, 1, 1)
  f.end_date Date.new(2999, 12, 31)
end

FactoryBot.define :entity_snapshot do |f|
  f.association :recordable, :factory => :entry
  f.association :user
end

FactoryBot.define :billable_event do |f|
  f.association :billable_eventable, :factory => :entry
  f.association :entity_snapshot
end

FactoryBot.define :invoiced_event do |f|
  f.association :billable_event
end

FactoryBot.define :non_invoiced_event do |f|
  f.association :billable_event
end

FactoryBot.define :vfi_invoice do |f|
  f.association :customer, :factory=>:company
  f.sequence :invoice_number
end

FactoryBot.define :vfi_invoice_line do |f|
  f.association :vfi_invoice
  f.sequence :line_number
  f.charge_description {FactoryBot.next :alpha_numeric}
  f.unit_price 5
  f.quantity 1
  f.charge_amount 1
end
FactoryBot.define :search_table_config do |f|
  f.name 'stc'
  f.sequence :page_uid
end

FactoryBot.define :folder do |f|
  f.base_object :order
  f.created_by :user
end
FactoryBot.define :aws_backup_session do |f|
end
FactoryBot.define :aws_snapshot do |f|
  f.association :aws_backup_session
end
FactoryBot.define :fiscal_month do |f|
  f.association :company
end
FactoryBot.define :attachment_archive_setup do |f|
  f.association :company
  f.output_path ''
end
FactoryBot.define :random_audit do |f|
  f.association :user
  f.association :search_setup
end

FactoryBot.define :business_validation_scheduled_job do |f|
  f.validatable :entry
end
FactoryBot.define :business_validation_schedule do |f|
  f.name 'schedule'
  f.module_type "Entry"
end

FactoryBot.define :one_time_alert do |f|
  f.association :user
end
FactoryBot.define :one_time_alert_log_entry do |f|
  f.association :one_time_alert
end

FactoryBot.define :tariff_classification do |f|
  f.association :country
end
FactoryBot.define :tariff_classification_rate do |f|
  f.association :tariff_classification
end
FactoryBot.define :monthly_statement do |f|
end
FactoryBot.define :daily_statement do |f|
  f.association :monthly_statement
end
FactoryBot.define :daily_statement_entry do |f|
  f.association :daily_statement
end
FactoryBot.define :unit_of_measure do |f|
  f.uom 'foo'
  f.description 'bar'
  f.system 'Customs Management'
end
FactoryBot.define :announcement do |f|
  f.title 'title'
  f.start_at DateTime.new(2020, 3, 15, 12, 0)
  f.end_at DateTime.new(2020, 3, 20, 15, 0)
end
FactoryBot.define :user_announcement do |f|
end
FactoryBot.define :user_announcement_marker do |f|
end

FactoryBot.define :runtime_log do |l|
end

FactoryBot.define :inbound_file do |file|
end
