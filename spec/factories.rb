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
  r
end
Factory.define :company do |c|
  c.sequence(:name) { |n| "cname#{n}"}
end
Factory.define :user do |f|  
  f.sequence(:username) { |n| "foo#{n}" }   
  f.password "foobar"  
  f.password_confirmation { |u| u.password }  
  f.sequence(:email) { |n| "foo#{n}@example.com" }  
  f.association :company
  f.tos_accept Time.now
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
Factory.define :shipment do |s|
  s.sequence(:reference)
  s.association :vendor, :factory => :company
end
Factory.define :sales_order do |s|
  s.sequence(:order_number)
  s.association :customer, :factory => :company
end
Factory.define :delivery do |d|
  d.sequence(:reference)
  d.association :customer, :factory => :company
end
Factory.define :linkable_attachment_import_rule do |a|
  a.sequence(:path)
  a.model_field_uid 'mfuid'
end
Factory.define :search_setup do |s|
  s.name  'search name'
  s.module_type  'Product'
  s.association :user
Factory.define :custom_definition do |c|
  c.label "customdef"
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
