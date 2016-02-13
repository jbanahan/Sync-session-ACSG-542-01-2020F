class ProductVendorAssignment < ActiveRecord::Base
  include CoreObjectSupport

  belongs_to :product
  belongs_to :vendor, class_name: 'Company'

  CORE_MODULE = CoreModule::PRODUCT_VENDOR_ASSIGNMENT

  dont_shallow_merge :ProductVendorAssignment, ['id','created_at','updated_at']

  def can_view? user
    return false unless self.vendor
    return self.vendor.can_view?(user)
  end

  def can_edit? user
    return false unless self.vendor && self.product
    return self.vendor.can_edit?(user) && self.product.can_edit?(user)
  end
end
