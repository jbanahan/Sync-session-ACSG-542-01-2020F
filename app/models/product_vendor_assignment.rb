class ProductVendorAssignment < ActiveRecord::Base
  include CoreObjectSupport

  belongs_to :product
  belongs_to :vendor, class_name: 'Company'

  dont_shallow_merge :ProductVendorAssignment, ['id','created_at','updated_at']

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
