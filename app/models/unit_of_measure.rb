# == Schema Information
#
# Table name: unit_of_measures
#
#  created_at  :datetime         not null
#  description :string(255)
#  id          :integer          not null, primary key
#  system      :string(255)
#  uom         :string(255)
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_unit_of_measures_on_uom_and_system  (uom,system)
#

class UnitOfMeasure < ActiveRecord::Base
  attr_accessible :uom, :description, :system
end
