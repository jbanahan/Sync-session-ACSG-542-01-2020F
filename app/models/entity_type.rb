# == Schema Information
#
# Table name: entity_types
#
#  created_at  :datetime         not null
#  id          :integer          not null, primary key
#  module_type :string(255)
#  name        :string(255)
#  updated_at  :datetime         not null
#

class EntityType < ActiveRecord::Base
  attr_accessible :module_type, :name

  has_many :entity_type_fields, :dependent => :destroy
  has_many :products, :dependent => :nullify
  validates :name, :presence => true, :uniqueness => true
end
