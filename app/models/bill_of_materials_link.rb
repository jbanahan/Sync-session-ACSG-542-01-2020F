class BillOfMaterialsLink < ActiveRecord::Base
  attr_accessible :child_product_id, :parent_product_id, :quantity
  belongs_to :parent_product, :class_name=>"Product", :touch=>true, :inverse_of=>:bill_of_materials_parents
  belongs_to :child_product, :class_name=>"Product", :touch=>true, :inverse_of=>:bill_of_materials_children
end
