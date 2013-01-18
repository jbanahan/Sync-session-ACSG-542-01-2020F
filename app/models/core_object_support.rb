module CoreObjectSupport
  def self.included(base)
    base.instance_eval("include CustomFieldSupport")
    base.instance_eval("include ShallowMerger")
    base.instance_eval("include EntitySnapshotSupport")
    base.instance_eval("has_many   :histories, :dependent => :destroy")
    base.instance_eval("has_many   :comments, :as => :commentable, :dependent => :destroy")
    base.instance_eval("has_many   :attachments, :as => :attachable, :dependent => :destroy") 	
    base.instance_eval("has_many   :linked_attachments, :as => :attachable, :dependent => :destroy")
    base.instance_eval("has_many   :linkable_attachments, :through => :linked_attachments")
    base.instance_eval("has_many   :item_change_subscriptions, :dependent => :destroy")
    base.instance_eval("has_many   :change_records, :as => :recordable")
    base.instance_eval("has_many :sync_records, :as => :syncable, :dependent=>:destroy")
    base.instance_eval("after_save :process_linked_attachments")

    base.instance_eval("scope :need_sync, lambda {|trading_partner| joins(\"LEFT OUTER JOIN sync_records ON sync_records.syncable_type = '\#{self.name}' and sync_records.syncable_id = \#{self.table_name}.id and sync_records.trading_partner = '\#{trading_partner}'\").where(\"sync_records.id is NULL OR sync_records.sent_at is NULL or sync_records.confirmed_at is NULL or sync_records.sent_at > sync_records.confirmed_at or \#{self.table_name}.updated_at > sync_records.sent_at \")}")
    base.instance_eval("scope :has_attachment, joins(\"LEFT OUTER JOIN linked_attachments ON linked_attachments.attachable_type = '\#{self.name}' AND linked_attachments.attachable_id = \#{self.table_name}.id LEFT OUTER JOIN attachments ON attachments.attachable_type = '\#{self.name}' AND attachments.attachable_id = \#{self.table_name}.id\").where('attachments.id is not null OR linked_attachments.id is not null').uniq")
  end


  def all_attachments
    r = []
    r += self.attachments.to_a
    self.linkable_attachments.each {|linkable| r << linkable.attachment}
    r.sort do |a,b|
      v = 0
      v = a.attachment_type <=> b.attachment_type if a.attachment_type && b.attachment_type
      v = a.attached_file_name <=> b.attached_file_name if v==0
      v = a.id <=> b.id if v==0
      v
    end
  end

  def process_linked_attachments
    LinkedAttachment.delay.create_from_attachable(self) if LinkableAttachmentImportRule.exists_for_class?(self.class)
  end

  # return link back url for this object (yes, this is a violation of MVC, but we need it for downloaded spreadsheets)
  def view_url
    raise "Cannot generate view_url because MasterSetup.request_host not set." unless MasterSetup.get.request_host
    raise "Cannot generate view_url because object id not set." unless self.id
    "http://#{MasterSetup.get.request_host}/#{self.class.table_name}/#{self.id}"
  end
end
