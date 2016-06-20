Factory.sequence :iso do |n|
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
Factory.sequence :alpha_numeric do |n|
  "ALPHA#{n}"
end
Factory.define :company do |c|
  c.sequence(:name) { |n| "cname#{n}"}
end
Factory.define :importer, parent: :company do |c|
  c.importer true
end
Factory.define :consignee, parent: :company do |c|
  c.consignee true
end
Factory.define :vendor, parent: :company do |c|
  c.vendor true
end
Factory.define :master_company, parent: :company do |c|
  c.master true
end
Factory.define :part_number_correlation do |c|
end
Factory.define :address do |a|
  a.name "MYaddr"
  a.association :country
  a.association :company
end
Factory.define :full_address, parent: :address do |a|
  a.line_1 '99 Fake Street'
  a.city 'Fakesville'
  a.state 'PA'
  a.postal_code '19191'
end
Factory.define :blank_address, class: Address do |a|
  a.association :company
end
Factory.define :user do |f|
  f.sequence(:username) { |n| "foo#{n}" }
  f.password "foobar"
  f.sequence(:email) { |n| "foo#{n}@example.com" }
  f.association :company
  f.api_auth_token "auth_token"
end
Factory.define :master_user, :parent=>:user do |f|
  f.association :company, :factory => :master_company
end
Factory.define :admin_user, :parent=>:master_user do |f|
  f.after_create do |u|
    u.admin = true
    u.save!
  end
end
Factory.define :sys_admin_user, :parent=>:master_user do |f|
  f.after_create do |u|
    u.admin = true
    u.sys_admin = true
    u.save!
  end
end
Factory.define :broker_user, :parent=>:user do |f|
  f.entry_view true
  f.broker_invoice_view true
  f.after_create {|u| u.company.update_attributes(:broker=>true)}
end
Factory.define :importer_user, :parent=>:user do |f|
  f.entry_view true
  f.broker_invoice_view true
  f.after_create {|u| u.company.update_attributes(:importer=>true)}
end
Factory.define :vendor_user, :parent=>:user do |f|
  f.after_create {|u| u.company.update_attributes(:vendor=>true)}
end
Factory.define :drawback_user, :parent=>:user do |f|
  f.drawback_view true
  f.drawback_edit true
  f.after_create {|u| u.company.update_attributes(:drawback=>true)}
end
Factory.define :user_template do |f|
  f.name 'mytemplate'
  f.template_json "{}"
end
Factory.define :country do |c|
  c.iso_code {Factory.next :iso}
  c.sequence(:name) {|n| "Country #{n}"}
end
Factory.define :region do |f|
end
Factory.define :official_tariff do |t|
  t.sequence(:hts_code) {|n| "123456#{n}"}
  t.full_description "description"
  t.association :country
end
Factory.define :product do |p|
  p.sequence(:unique_identifier) {|n| "uid#{n}"}
end
Factory.define :classification do |c|
  c.association :product
  c.association :country
end
Factory.define :tariff_record do |t|
  t.association :classification
end
Factory.define :product_group do |f|
  f.sequence(:name)
end
Factory.define :variant do |f|
  f.sequence(:variant_identifier)
  f.association :product
end
Factory.define :plant_variant_assignment do |f|
  f.association :variant
  f.association :plant
end
Factory.define :change_record do |t|
  t.association :file_import_result
end
Factory.define :change_record_message do |t|
  t.association :change_record
end
Factory.define :linkable_attachment do |t|
  t.model_field_uid 'mfuid'
  t.value 'val'
end
Factory.define :linked_attachment do |t|
  t.association :linkable_attachment
  t.after_build do |la|
    la.attachable = Factory(:product)
  end
end
Factory.define :order do |o|
  o.sequence(:order_number)
  o.association :vendor, :factory => :company
end
Factory.define :order_line do |o|
  o.association :product
  o.quantity 1
  o.sequence(:line_number)
  o.association :order
end
Factory.define :shipment do |s|
  s.sequence(:reference)
  s.association :vendor, :factory => :company
end
Factory.define :shipment_line do |s|
  s.sequence(:line_number)
  s.quantity 1
  s.association :product
  s.association :shipment
end
Factory.define :booking_line do |s|
  s.sequence(:line_number)
  s.quantity 1
  s.association :shipment
end
Factory.define :carton_set do |f|
  f.sequence(:starting_carton)
  f.association :shipment
end
Factory.define :sales_order do |s|
  s.sequence(:order_number)
  s.association :customer, :factory => :company
end
Factory.define :sales_order_line do |s|
  s.sequence(:line_number)
  s.quantity 1
  s.association :product
  s.association :sales_order
end
Factory.define :delivery do |d|
  d.sequence(:reference)
  d.association :customer, :factory => :company
end
Factory.define :delivery_line do |d|
  d.sequence(:line_number)
  d.quantity 1
  d.association :product
  d.association :delivery
end
Factory.define :drawback_import_line do |d|
  d.sequence :line_number
  d.quantity 1
  d.association :product
end
Factory.define :linkable_attachment_import_rule do |a|
  a.sequence(:path)
  a.model_field_uid 'mfuid'
end
Factory.define :search_setup do |s|
  s.name  'search name'
  s.module_type  'Product'
  s.association :user
end
Factory.define :custom_report do |s|
  s.name  'custom report name'
  s.association :user
end
Factory.define :search_schedule do |s|
  s.association :search_setup
end
Factory.define :search_criterion do |f|
  f.model_field_uid 'prod_uid'
  f.operator 'eq'
  f.value 'x'
end
Factory.define :sort_criterion do |f|
  f.model_field_uid 'prod_uid'
end
Factory.define :search_column do |f|
  f.model_field_uid 'prod_uid'
end
Factory.define :search_template do |f|
  f.name 'search_name'
  # {name:ss.name,
  #     module_type:ss.module_type,
  #     include_links:ss.include_links,
  #     no_time:ss.no_time
  #   }
  f.search_json '{"name":"search_name","module_type":"Order","include_links":true,"no_time":true}'
end
Factory.define :custom_definition do |c|
  c.sequence(:label)
  c.data_type "string"
  c.module_type "Product"
end
Factory.define :imported_file do |f|
  f.module_type "Product"
  f.starting_row  1
  f.starting_column  1
  f.update_mode "any"
end
Factory.define :file_import_result do |f|
  f.association :imported_file
  f.association :run_by, :factory => :user
end
Factory.define :custom_file do |f|
end
Factory.define :power_of_attorney do |poa|
  poa.association :user
  poa.association :company
  poa.start_date "2011-12-01"
  poa.expiration_date "2011-12-31"
  poa.attachment_file_name "SpecAttachmentDocument.odt"
end
Factory.define :entry do |f|

end
Factory.define :commercial_invoice do |f|
  f.association :entry
end
Factory.define :commercial_invoice_line do |f|
  f.association :commercial_invoice
  f.sequence :line_number
end
Factory.define :commercial_invoice_tariff do |f|
  f.association :commercial_invoice_line
end
Factory.define :broker_invoice do |f|
  f.sequence :invoice_number
  f.association :entry
end
Factory.define :broker_invoice_line do |f|
  f.association :broker_invoice
  f.charge_description {Factory.next :alpha_numeric}
  f.charge_code {Factory.next :alpha_numeric}
  f.charge_amount 1
end
Factory.define :port do |f|
  f.schedule_k_code '23456'
  f.schedule_d_code '1424'
  f.name 'abc def'
end
Factory.define :message do |f|
  f.subject 'ABC'
  f.body 'DEF'
  f.association :user
end
Factory.define :attachment do |f|
  f.attached_file_name "foo.bar"
  f.attached_content_type "image/png"
end
Factory.define :email_attachment do |f|
  f.email "ea@example.com"
  f.after_create { |ea| ea.attachment = Factory(:attachment, :attachable => ea); ea.save }
end
Factory.define :survey do |f|
  f.association :company
  f.association :created_by, :factory=>:user
end
Factory.define :question do |f|
  f.association :survey
  f.content "My question content"
end
Factory.define :survey_response do |f|
  f.association :user
  f.association :survey
  f.name 'joe smith'
  f.address 'xyz'
  f.phone '1234567890'
  f.fax '1234567890'
  f.email 'a@b.com'
end
Factory.define :corrective_action_plan do |f|
  f.association :survey_response
end
Factory.define :answer do |f|
  f.association :question
  f.association :survey_response
end
Factory.define :commercial_invoice_map do |f|
  f.source_mfid "prod_uid"
  f.destination_mfid "cil_part_number"
end
Factory.define :support_ticket do |f|
  f.association :requestor, :factory => :user
  f.subject "at least 10 characters"
end
Factory.define :survey_subscription do |f|
  f.association :survey
  f.association :user
end
Factory.define :ftp_session do |f|
  f.username "foo"
  f.server "foo.example.com"
  f.file_name "bar.txt"
  f.log "test log"
  f.data "sample data"
end
Factory.define :duty_calc_export_file_line do |f|

end
Factory.define :duty_calc_import_file do |f|
  f.association :importer, :factory => :company
end
Factory.define :duty_calc_export_file do |f|
  f.association :importer, :factory => :company
end
Factory.define :charge_code do |f|
  f.sequence :code
  f.description "cc description"
end
Factory.define :drawback_claim do |f|
  f.name "dname"
  f.association :importer, :factory => :company
end
Factory.define :security_filing do |f|
  f.association :importer, :factory => :company
end
Factory.define :schedulable_job do |f|

end
Factory.define :project do |f|

end
Factory.define :project_update do |f|
  f.association :project
end
Factory.define :project_deliverable do |f|
  f.association :project
end
Factory.define :project_set do |f|
  f.sequence :name
end
Factory.define :business_validation_template do |f|
  f.module_type 'Entry'
end
Factory.define :business_validation_rule do |f|
  f.association :business_validation_template
end
Factory.define :business_validation_result do |f|
  f.association :business_validation_template
end
Factory.define :business_validation_rule_result do |f|
  f.association :business_validation_rule
  f.after_create {|rr|
    bvt = rr.business_validation_rule.business_validation_template
    rr.business_validation_result = bvt.business_validation_results.create!
    rr.save!
  }
end
Factory.define :container do |f|
  f.container_number {Factory.next :alpha_numeric}
  f.association :entry
end
Factory.define :event_subscription do |f|
  f.association :user
  f.event_type 'ORDER_COMMENT_CREATE'
end
Factory.define :email, class: OpenStruct do |f|
  # Assumes Griddler.configure.to is :hash (default)
  f.to [{ full: 'to_user@email.com', email: 'to_user@email.com', token: 'to_user', host: 'email.com', name: nil }]
  f.from 'user@email.com'
  f.subject 'email subject'
  f.body 'Hello!'
  f.attachments {[]}
end

Factory.define :group do |f|
  f.sequence(:system_code) {|c| "code#{c}"}
  f.name "Group Name"
end

#workflow instance needs to be able to load a workflow decider
module OpenChain
  class MockFactoryDecider
    def self.update_workflow! obj, user
      nil
    end
  end
end
Factory.define :workflow_instance do |f|
  f.name 'MyWorkflowInstance'
  f.workflow_decider_class 'OpenChain::MockFactoryDecider'
  f.association :base_object, factory: :order
end
Factory.define :workflow_task do |f|
  f.name 'MyWorkflowTask'
  f.task_type_code 'FACT_TASK'
  f.association :workflow_instance
  f.association :group
  f.test_class_name 'OpenChain::WorkflowTester::AttachmentTypeWorkflowTest'
  f.payload_json '{"attachment_type":"Sample"}'
end

Factory.define :state_toggle_button do |f|

end

Factory.define :plant do |f|
  f.sequence(:name) { |n| "pname#{n}"}
  f.association :company
end
Factory.define :plant_product_group_assignment do |f|
  f.association :plant
  f.association :product_group
end

Factory.define :sent_email do |f|
  f.sequence(:email_subject) { |n| "subject#{n}" }
  f.sequence(:email_to) { |n| "recipient#{n}" }
  f.sequence(:email_from) { |n| "sender#{n}" }
end

Factory.define :summary_statement do |f|
  f.sequence(:statement_number) { |n| "statement_#{n}" }
  f.association :customer, :factory => :company
end

Factory.define :user_manual do |f|
  f.name "MyManual"
end

Factory.define :product_vendor_assignment do |f|
  f.association :product
  f.association :vendor
end

Factory.define :custom_view_template do |f|
  f.sequence(:template_identifier) {|n| "t_#{n}"}
  f.sequence(:template_path) {|n| "tp_#{n}"}
end

Factory.define :trade_lane do |f|
  f.association :origin_country, factory: :country
  f.association :destination_country, factory: :country
end

Factory.define :trade_preference_program do |f|
  f.name 'TPP'
  f.association :origin_country, factory: :country
  f.association :destination_country, factory: :country
end

Factory.define :tpp_hts_override do |f|
  f.association :trade_preference_program
  f.hts_code '1234567890'
  f.start_date Date.new(1900,1,1)
  f.end_date Date.new(2999,12,31)
end

Factory.define :product_trade_preference_program do |f|
  f.association :product
  f.association :trade_preference_program
end

Factory.define :official_tariff_spi do |f|
  f.association :official_tariff
end

Factory.define :product_rate_override do |f|
  f.association :product
  f.start_date Date.new(1900,1,1)
  f.end_date Date.new(2999,12,31)
end
