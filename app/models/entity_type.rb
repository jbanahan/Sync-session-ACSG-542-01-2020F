class EntityType < ActiveRecord::Base
  has_many :entity_type_fields, :dependent => :destroy
end
