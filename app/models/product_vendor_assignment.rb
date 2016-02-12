class ProductVendorAssignment < ActiveRecord::Base
  belongs_to :product
  belongs_to :vendor, class_name: 'Company'
end
