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
  p.sequence(:unique_identifier) {|n| "#{n}"}
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
