Factory.sequence :iso do |n|
  @iso_seq_1 ||= "A"
  @iso_seq_2 ||= "A"
  if @iso_seq_2 == "Z"
    @iso_seq_2 = "A"
    @iso_seq_1 = @iso_seq_1.succ
  end
  r = "#{@iso_seq_1}#{@iso_seq_2}"
  @iso_seq_1 = @iso_seq_1.succ
  @iso_seq_2 = @iso_seq_2.succ
  r[0,2]
end
Factory.define :company do |c|
  c.sequence(:name) { |n| "cname#{n}"}
end
Factory.define :address do |a|
  a.name "MYaddr"
  a.association :country
  a.association :company
end
Factory.define :user do |f|  
  f.sequence(:username) { |n| "foo#{n}" }   
  f.password "foobar"  
  f.password_confirmation { |u| u.password }  
  f.sequence(:email) { |n| "foo#{n}@example.com" }  
  f.association :company
end  
Factory.define :country do |c|
  c.iso_code {Factory.next :iso}
  c.sequence(:name) {|n| "Country #{n}"}
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
Factory.define :linkable_attachment do |t|
  t.model_field_uid 'mfuid'
  t.value 'val'
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
Factory.define :search_schedule do |s|
  s.association :search_setup
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
Factory.define :broker_invoice do |f|
  f.association :entry
end
Factory.define :broker_invoice_line do |f|
  f.association :broker_invoice
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
