class ProductGroup < ActiveRecord::Base
  has_many :vendor_product_group_assignments, inverse_of: :product_group
  has_many :vendors, through: :vendor_product_group_assignments

  validates :name, presence: true, uniqueness: true

  before_destroy :validate_in_use

  #linked to another object?
  def in_use?
    !self.vendor_product_group_assignments.empty?
  end

  def validate_in_use
    if self.in_use?
      errors[:base] << "Cannot delete Product Group while in use."
      return false
    end
    return true
  end
  private :validate_in_use
end
