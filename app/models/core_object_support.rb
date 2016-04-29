module CoreObjectSupport
  def self.included(base)
    base.extend ClassMethods
    base.instance_eval("attr_accessor :dont_process_linked_attachments")
    base.instance_eval("include CustomFieldSupport")
    base.instance_eval("include ShallowMerger")
    base.instance_eval("include EntitySnapshotSupport")
    base.instance_eval("include BroadcastsEvents")
    base.instance_eval("include UpdateModelFieldsSupport")
    base.instance_eval("include FingerprintSupport")
    # Allow new instances to start up (prior to migrations run will not have histories or item change subscriptions tables)
    if ActiveRecord::Base.connection.table_exists?('histories') && History.column_names.include?(base.name.foreign_key)
      base.instance_eval("has_many   :histories, :dependent => :destroy")
    end
    if ActiveRecord::Base.connection.table_exists?('item_change_subscriptions') && ItemChangeSubscription.column_names.include?(base.name.foreign_key)
      base.instance_eval("has_many   :item_change_subscriptions, :dependent => :destroy")
    end
    base.instance_eval("has_many   :comments, :as => :commentable, :dependent => :destroy")
    base.instance_eval("has_many   :attachments, :as => :attachable, :dependent => :destroy")
    base.instance_eval("has_many   :attachment_process_jobs, :as => :attachable, :dependent => :destroy")
    base.instance_eval("has_many   :linked_attachments, :as => :attachable, :dependent => :destroy")
    base.instance_eval("has_many   :linkable_attachments, :through => :linked_attachments")
    base.instance_eval("has_many   :change_records, :as => :recordable")
    base.instance_eval("has_many :sync_records, :as => :syncable, :dependent=>:destroy, :autosave=>true, :inverse_of => :syncable")
    base.instance_eval("has_many :business_validation_results, as: :validatable, dependent: :destroy")
    base.instance_eval("has_many :workflow_instances, as: :base_object, dependent: :destroy, inverse_of: :base_object")
    base.instance_eval("has_one :workflow_processor_run, as: :base_object, dependent: :destroy, inverse_of: :base_object")
    base.instance_eval("has_many :survey_responses, as: :base_object, dependent: :destroy, inverse_of: :base_object")
    base.instance_eval("after_save :process_linked_attachments")

    base.instance_eval("scope :need_sync, lambda {|trading_partner| joins(need_sync_join_clause(trading_partner)).where(need_sync_where_clause())}")
    base.instance_eval("scope :has_attachment, joins(\"LEFT OUTER JOIN linked_attachments ON linked_attachments.attachable_type = '\#{self.name}' AND linked_attachments.attachable_id = \#{self.table_name}.id LEFT OUTER JOIN attachments ON attachments.attachable_type = '\#{self.name}' AND attachments.attachable_id = \#{self.table_name}.id\").where('attachments.id is not null OR linked_attachments.id is not null').uniq")
  end

  def core_module
    CoreModule.find_by_object self
  end

  def business_rules_state
    r = nil
    self.business_validation_results.each do |bvr|
      r = BusinessValidationResult.worst_state r, bvr.state
    end
    r
  end

  def failed_business_rules
    self.business_validation_results.
      joins(business_validation_rule_results: [:business_validation_rule]).
      where(business_validation_rule_results: {state: "Fail"}).
      uniq.
      order("business_validation_rules.name").
      pluck("business_validation_rules.name")
  end

  def any_failed_rules?
    self.business_validation_results.any? {|r| r.failed? }
  end

  def attachment_types
    self.attachments.where("LENGTH(RTRIM(IFNULL(attachment_type, ''))) > 0").order(:attachment_type).uniq.pluck(:attachment_type)
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
    LinkedAttachment.delay(:priority=>600).create_from_attachable_by_class_and_id(self.class,self.id) if !self.dont_process_linked_attachments && LinkableAttachmentImportRule.exists_for_class?(self.class)
  end

  # return link back url for this object (yes, this is a violation of MVC, but we need it for downloaded file links)
  def view_url
    self.class.excel_url self.id
  end

  #return the relative url to the view page for the object
  def relative_url
    self.class.relative_url self.id
  end

  #return an excel friendly link to the object that handles Excel session bugs
  def excel_url
    self.class.excel_url self.id
  end

  module ClassMethods
    def find_by_custom_value custom_definition, value
      self.joins(:custom_values).where('custom_values.custom_definition_id = ?',custom_definition.id).where("custom_values.#{custom_definition.data_type}_value = ?",value).first
    end
    def need_sync_join_clause trading_partner, join_table = self.table_name
      sql = "LEFT OUTER JOIN sync_records ON sync_records.syncable_type = ? and sync_records.syncable_id = #{join_table}.id and sync_records.trading_partner = ?"
      sanitize_sql_array([sql, name, trading_partner])
    end

    def need_sync_where_clause join_table = self.table_name, sent_at_before = nil
      # sent_at_before is for cases where we don't want to resend product records prior to a certain timeframe OR
      # cases where we're splitting up file sends on product count (batching) and don't want to resend ones we just
      # sent in a previous batch.
      query = 
      "(sync_records.id is NULL OR
         (
            (sync_records.sent_at is NULL OR
             sync_records.confirmed_at is NULL OR
             sync_records.sent_at > sync_records.confirmed_at OR
             #{join_table}.updated_at > sync_records.sent_at
            ) AND
            (sync_records.ignore_updates_before IS NULL OR
             sync_records.ignore_updates_before < #{join_table}.updated_at)
            "
      if sent_at_before.respond_to?(:acts_like_time?) || sent_at_before.respond_to?(:acts_like_date?)
        query += " AND
            (sync_records.sent_at IS NULL OR sync_records.sent_at < '#{sent_at_before.to_s(:db)}')"
      end

      query + "
        )
      )"
    end

    def excel_url object_id
      XlsMaker.excel_url relative_url(object_id)
    end

    def relative_url object_id
      raise "Cannot generate view_url because object id not set." unless object_id
      "/#{self.table_name}/#{object_id}"
    end
  end
end
