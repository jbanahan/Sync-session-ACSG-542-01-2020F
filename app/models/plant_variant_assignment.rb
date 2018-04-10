# == Schema Information
#
# Table name: plant_variant_assignments
#
#  created_at :datetime         not null
#  disabled   :boolean
#  id         :integer          not null, primary key
#  plant_id   :integer          not null
#  updated_at :datetime         not null
#  variant_id :integer          not null
#
# Indexes
#
#  index_plant_variant_assignments_on_disabled                 (disabled)
#  index_plant_variant_assignments_on_plant_id                 (plant_id)
#  index_plant_variant_assignments_on_plant_id_and_disabled    (plant_id,disabled)
#  index_plant_variant_assignments_on_variant_id               (variant_id)
#  index_plant_variant_assignments_on_variant_id_and_disabled  (variant_id,disabled)
#

class PlantVariantAssignment < ActiveRecord::Base
  include CustomFieldSupport
  include ShallowMerger
  include UpdateModelFieldsSupport

  belongs_to :plant, inverse_of: :plant_variant_assignments
  belongs_to :variant, inverse_of: :plant_variant_assignments

  scope :enabled, where('disabled = ? OR disabled is null',false)

  dont_shallow_merge :PlantVariantAssignment, ['id','created_at','updated_at']


  def self.search_secure user, base_object
    base_object.where(search_where(user))
  end

  # where clause for search secure
  def self.search_where user
    "(plant_variant_assignments.plant_id IN (select id from plants where #{Plant.search_where(user)}))"
  end

  def can_view?(user)
    self.plant && self.plant.can_view?(user)
  end
end
