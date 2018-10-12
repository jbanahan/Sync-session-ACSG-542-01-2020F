module CoreObjectSupport
  extend ActiveSupport::Concern

  included do
    include CustomFieldSupport
    include ShallowMerger
    include EntitySnapshotSupport
    include BroadcastsEvents
    include UpdateModelFieldsSupport
    include FingerprintSupport

    attr_accessor :dont_process_linked_attachments

    has_many :comments, as: :commentable, dependent: :destroy
    has_many :attachments, as: :attachable, dependent: :destroy
    has_many :attachment_process_jobs, as: :attachable, dependent: :destroy, class_name: AttachmentProcessJob
    has_many :linked_attachments, as: :attachable, dependent: :destroy
    has_many :linkable_attachments, through: :linked_attachments
    has_many :change_records, as: :recordable
    has_many :business_rule_snapshots, as: :recordable
    has_many :sync_records, as: :syncable, dependent: :destroy, autosave: true, inverse_of: :syncable
    has_many :business_validation_results, as: :validatable, dependent: :destroy
    has_many :survey_responses, as: :base_object, dependent: :destroy, inverse_of: :base_object
    has_many :folders, as: :base_object, dependent: :destroy, inverse_of: :base_object, conditions: "folders.archived is null OR folders.archived = 0"
    has_many :billable_events, :as => :billable_eventable, :class_name => 'BillableEvent', :dependent => :destroy

    after_save :process_linked_attachments

    # Allow new instances to start up (prior to migrations run will not have histories or item change subscriptions tables)
    if ActiveRecord::Base.connection.table_exists?('histories') && History.column_names.include?(self.name.foreign_key)
      has_many :histories, dependent: :destroy
    end

    if ActiveRecord::Base.connection.table_exists?('item_change_subscriptions') && ItemChangeSubscription.column_names.include?(self.name.foreign_key)
      has_many :item_change_subscriptions, dependent: :destroy
    end

    scope :need_sync, lambda {|trading_partner| joins(need_sync_join_clause(trading_partner)).where(need_sync_where_clause()) }
    scope :has_attachment, joins("LEFT OUTER JOIN linked_attachments ON linked_attachments.attachable_type = '#{self.name}' AND linked_attachments.attachable_id = #{self.table_name}.id LEFT OUTER JOIN attachments ON attachments.attachable_type = '#{self.name}' AND attachments.attachable_id = #{self.table_name}.id").where('attachments.id is not null OR linked_attachments.id is not null').uniq
  end

  def core_module
    CoreModule.find_by_object self
  end

  def business_rules_state_for_user user
    if user.view_all_business_validation_results?
      business_rules_state
    elsif user.view_business_validation_results?
      business_rules_state include_private: false
    else
      nil
    end
  end

  def business_rules_state include_private:true
    r = nil
    results = self.business_validation_results.send(include_private ? :all : :public)
    results.each do |bvr|
      r = BusinessValidationResult.worst_state r, bvr.state
    end
    r
  end

  def business_rules state, include_private:true
    self.business_validation_results.
      joins(:business_validation_template).
      joins(business_validation_rule_results: [:business_validation_rule]).
      where(business_validation_rule_results: {state: state}).
      where(include_private || {business_validation_templates: {private: [nil, false]}}).
      uniq.
      order("business_validation_rules.name").
      pluck("business_validation_rules.name")
  end

  def business_rule_templates state, include_private:true
    self.business_validation_results.
      joins(:business_validation_template).
      where(business_validation_results: {state: state}).
      where(include_private || {business_validation_templates: {private: [nil, false]}}).
      uniq.
      order("business_validation_templates.name").
      pluck("business_validation_templates.name")
  end

  def any_failed_rules?
    self.business_validation_results.any? {|r| r.failed? }
  end

  def can_run_validations? user
    can_edit_all_rule_results = true
    business_validation_results.each do |bvr|
      bvr.business_validation_rule_results.each { |bvrr| can_edit_all_rule_results = false unless bvrr.can_edit? user }
    end
    can_edit_all_rule_results
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

  def clear_attributes exceptions
    skip = ([:id, :created_at, :updated_at] + exceptions).map(&:to_s)
    attrs_to_erase = {}
    self.attributes.keys.each { |att| attrs_to_erase[att] = nil unless att.match(/_id$/) || (skip.member? att) }
    self.assign_attributes(attrs_to_erase, :without_protection => true)
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

  # Splits a string into an array based on newline characters it contains within it.  Strips leading whitespace from
  # most internal values, but not trailing whitespace, nor is leading whitespace removed from the first value found.
  def split_newline_values string_containing_newlines
    string_containing_newlines.blank? ? [] : string_containing_newlines.split(/\r?\n */)
  end

  module ClassMethods
    def find_by_custom_value custom_definition, value
      self.joins(:custom_values).where('custom_values.custom_definition_id = ?',custom_definition.id).where("custom_values.#{custom_definition.data_type}_value = ?",value).first
    end

    def has_never_been_synced_where_clause
      # This is solely for the cause where we only ever want to sync an object a single time...therefore, we ONLY want to return results that either
      # do not have a sync record or the sync record sent at date is null - sent_date is null is to allow for clearing and manual resends
      "sync_records.id IS NULL OR sync_records.sent_at IS NULL"
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
