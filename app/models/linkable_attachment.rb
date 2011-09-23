class LinkableAttachment < ActiveRecord::Base
  has_one :attachment, :as => :attachable, :dependent => :destroy

  validates :model_field_uid, :presence => true
  validates :value, :presence => true

  #get a distinct list of model_field_uids in database
  def self.model_field_uids
    LinkableAttachment.find_by_sql('SELECT DISTINCT model_field_uid FROM linkable_attachments').collect {|a| a.model_field_uid} 
  end

  #get the associated ModelField object (or nil if it doesn't exist)
  def model_field
  
  end
end
