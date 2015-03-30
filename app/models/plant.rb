class Plant < ActiveRecord::Base
  include CoreObjectSupport
  belongs_to :company, inverse_of: :plants, touch: true

  has_many :plant_product_group_assignments, inverse_of: :plant, dependent: :destroy
  has_many :product_groups, through: :plant_product_group_assignments

  before_destroy :validate_in_use

  def unassigned_product_groups
    return ProductGroup.scoped if self.id.nil?
    ProductGroup.
      where("product_groups.id NOT IN (SELECT plant_product_group_assignments.product_group_id FROM plant_product_group_assignments WHERE plant_product_group_assignments.plant_id = #{self.id})")
  end

  def can_view? user
    return false unless self.company
    return true if self.company.can_view?(user)
    return true if self.company.can_view_as_vendor?(user)
    return false
  end

  def can_edit? user
    return false unless self.company
    return true if self.company.can_edit?(user)
  end

  def can_attach? user
    return false unless self.company
    return self.company.can_attach?(user)
  end

  # can this logically be deleted
  def in_use?
    false
  end


  def validate_in_use
    if self.in_use?
      errors[:base] << "Cannot delete Plant while in use."
      return false
    end
    return true
  end
  private :validate_in_use
end
