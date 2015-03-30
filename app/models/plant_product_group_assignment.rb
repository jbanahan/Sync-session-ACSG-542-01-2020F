class PlantProductGroupAssignment < ActiveRecord::Base
  include CoreObjectSupport

  belongs_to :plant, inverse_of: :plant_product_group_assignments, touch: true
  belongs_to :product_group, inverse_of: :plant_product_group_assignments

  def can_view? user
    return false unless self.plant
    return self.plant.can_view?(user)
  end

  def can_edit? user
    return false unless self.plant
    return self.plant.can_edit?(user)
  end
end
