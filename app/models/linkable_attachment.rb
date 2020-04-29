# == Schema Information
#
# Table name: linkable_attachments
#
#  attachment_id   :integer
#  created_at      :datetime         not null
#  id              :integer          not null, primary key
#  model_field_uid :string(255)
#  updated_at      :datetime         not null
#  value           :string(255)
#
# Indexes
#
#  linkable_attachment_id  (attachment_id)
#  linkable_mfuid          (model_field_uid)
#

class LinkableAttachment < ActiveRecord::Base
  attr_accessible :attachment_id, :model_field_uid, :value

  has_one :attachment, :as => :attachable, :dependent => :destroy
  has_many :linked_attachments

  validates :model_field_uid, :presence => true
  validates :value, :presence => true

  after_save :update_cache
  after_save :build_links

  # get a distinct list of model_field_uids in database
  def self.model_field_uids
    m = CACHE.get('LinkableAttachment:model_field_uids')
    m = LinkableAttachment.uniq.pluck(:model_field_uid) unless m
    m.blank? ? [] : m
  end

  # get the associated ModelField object (or nil if it doesn't exist)
  def model_field
    mf = ModelField.find_by_uid(self.model_field_uid)
    mf.blank? ? nil : mf
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
    CACHE.set("LinkableAttachment:model_field_uids", current)
  end
  def build_links
    LinkedAttachment.delay.create_from_linkable_attachment self
  end
end
