# == Schema Information
#
# Table name: product_vendor_assignments
#
#  created_at :datetime         not null
#  id         :integer          not null, primary key
#  product_id :integer
#  updated_at :datetime         not null
#  vendor_id  :integer
#
# Indexes
#
#  index_product_vendor_assignments_on_product_id                (product_id)
#  index_product_vendor_assignments_on_vendor_id                 (vendor_id)
#  index_product_vendor_assignments_on_vendor_id_and_product_id  (vendor_id,product_id) UNIQUE
#

class ProductVendorAssignment < ActiveRecord::Base
  attr_accessor :dont_process_linked_attachments

  include CoreObjectSupport

  belongs_to :product
  belongs_to :vendor, class_name: 'Company'

  dont_shallow_merge :ProductVendorAssignment, ['id', 'created_at', 'updated_at']

  def can_view? user
    return false unless self.vendor
    return self.vendor.can_view?(user)
  end

  def can_edit? user
    return false unless self.vendor && self.product
    return self.vendor.can_edit?(user) && self.product.can_edit?(user)
  end

  def self.search_secure user, base_object
    base_object.where search_where user
  end

  def self.search_where user
    return "1=1" if user.company.master?
    "(product_vendor_assignments.vendor_id IN (SELECT id FROM companies WHERE #{Company.search_where(user)}))"
  end

end
