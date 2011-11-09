class LinkableAttachment < ActiveRecord::Base
  has_one :attachment, :as => :attachable, :dependent => :destroy
  has_many :linked_attachments

  validates :model_field_uid, :presence => true
  validates :value, :presence => true

  after_save :update_cache
  after_save :build_links

  #get a distinct list of model_field_uids in database
  def self.model_field_uids
    m = CACHE.get('LinkableAttachment:model_field_uids')
    m = LinkableAttachment.find_by_sql('SELECT DISTINCT model_field_uid FROM linkable_attachments').collect {|a| a.model_field_uid} unless m
    m.blank? ? [] : m
  end

  #get the associated ModelField object (or nil if it doesn't exist)
  def model_field
    mf = ModelField.find_by_uid(self.model_field_uid)
    mf
  end

  def can_view? user
    r = false
    linked_attachments.each do |linked|
      if linked.attachable.can_view? user
        r = true
        break
      end
    end
    r
  end

  private
  def update_cache
    current = LinkableAttachment.model_field_uids
    current << self.model_field_uid
    current.uniq!
    CACHE.set("LinkableAttachment:model_field_uids",current)
  end
  def build_links
    LinkedAttachment.delay.create_from_linkable_attachment self
  end
end
