# == Schema Information
#
# Table name: plant_product_group_assignments
#
#  created_at       :datetime         not null
#  id               :integer          not null, primary key
#  plant_id         :integer
#  product_group_id :integer
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_plant_product_group_assignments_on_plant_id          (plant_id)
#  index_plant_product_group_assignments_on_product_group_id  (product_group_id)
#

class PlantProductGroupAssignment < ActiveRecord::Base
  include CoreObjectSupport

  attr_accessible :plant_id, :product_group_id

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

  def plant_name
    self.plant ? self.plant.name : nil
  end

  def product_group_name
    self.product_group ? self.product_group.name : nil
  end
end
