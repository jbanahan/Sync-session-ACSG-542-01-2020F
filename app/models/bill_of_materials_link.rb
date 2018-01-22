# == Schema Information
#
# Table name: bill_of_materials_links
#
#  id                :integer          not null, primary key
#  parent_product_id :integer
#  child_product_id  :integer
#  quantity          :integer
#
# Indexes
#
#  index_bill_of_materials_links_on_child_product_id   (child_product_id)
#  index_bill_of_materials_links_on_parent_product_id  (parent_product_id)
#

class BillOfMaterialsLink < ActiveRecord::Base
  attr_accessible :child_product_id, :parent_product_id, :quantity
  belongs_to :parent_product, :class_name=>"Product", :touch=>true, :inverse_of=>:bill_of_materials_parents
  belongs_to :child_product, :class_name=>"Product", :touch=>true, :inverse_of=>:bill_of_materials_children
end
