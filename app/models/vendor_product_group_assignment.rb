class VendorProductGroupAssignment < ActiveRecord::Base
  include CoreObjectSupport

  belongs_to :vendor, class_name: 'Company', inverse_of: :vendor_product_group_assignments
  belongs_to :product_group, inverse_of: :vendor_product_group_assignments

  validates :product_group_id, uniqueness: {scope: :vendor_id}

  def can_view? user
    return false unless self.vendor
    self.vendor.can_view_as_vendor?(user)
  end
end
