# == Schema Information
#
# Table name: entity_types
#
#  id          :integer          not null, primary key
#  name        :string(255)
#  module_type :string(255)
#  created_at  :datetime
#  updated_at  :datetime
#

class EntityType < ActiveRecord::Base
  has_many :entity_type_fields, :dependent => :destroy
  has_many :products, :dependent => :nullify
  validates :name, :presence => true, :uniqueness => true   
end
