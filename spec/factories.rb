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
  c.sequence(:iso_code) {|n| "A#{n}"}
  c.sequence(:name) {|n| "Country #{n}"}
end
