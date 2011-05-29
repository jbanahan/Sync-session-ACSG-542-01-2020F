class EntityTypeField < ActiveRecord::Base
  belongs_to :entity_type

  validates_presence_of :entity_type_id
  validates_presence_of :model_field_uid

  after_commit :reset_cache
  
  def self.cached_entity_type_ids model_field
    o = CACHE.get "EntityTypeField:etids:#{model_field.uid}"
    if o.nil?
     o = EntityTypeField.where(:model_field_uid=>model_field.uid).collect {|etf| etf.entity_type_id}
     CACHE.set "EntityTypeField:etids:#{model_field.uid}", o
    end
    o
  end

  private
  def reset_cache
    unless self.model_field_uid.blank?
      CACHE.delete "EntityTypeField:etids:#{self.model_field_uid}"
      EntityTypeField.cached_entity_type_ids ModelField.find_by_uid self.model_field_uid
    end
  end

end
