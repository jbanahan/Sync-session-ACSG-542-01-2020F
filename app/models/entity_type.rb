class EntityType < ActiveRecord::Base
  has_many :entity_type_fields, :dependent => :destroy
  has_many :products, :dependent => :nullify
  validates :name, :presence => true, :uniqueness => true   
end
