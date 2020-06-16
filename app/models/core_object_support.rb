module CoreObjectSupport
  extend ActiveSupport::Concern

  included do
    include CustomFieldSupport
    include ShallowMerger
    include EntitySnapshotSupport
    include BroadcastsEvents
    include UpdateModelFieldsSupport
    include FingerprintSupport
    include ConstantTextSupport

    attr_accessor :dont_process_linked_attachments

    has_many :comments, -> { order(created_at: :desc) }, as: :commentable, dependent: :destroy
    has_many :attachments, as: :attachable, dependent: :destroy, inverse_of: :attachable
    has_many :attachment_process_jobs, as: :attachable, dependent: :destroy, class_name: AttachmentProcessJob
    has_many :linked_attachments, as: :attachable, dependent: :destroy
    has_many :linkable_attachments, through: :linked_attachments
    has_many :change_records, as: :recordable
    has_many :sync_records, as: :syncable, dependent: :destroy, autosave: true, inverse_of: :syncable
    has_many :business_validation_results, as: :validatable, dependent: :destroy
    has_many :survey_responses, as: :base_object, dependent: :destroy, inverse_of: :base_object
    has_many :folders, -> { where(archived: [nil, 0]) }, as: :base_object, dependent: :destroy, inverse_of: :base_object
    has_many :billable_events, :as => :billable_eventable, :class_name => 'BillableEvent', :dependent => :destroy
    has_many :business_validation_scheduled_jobs, as: :validatable, dependent: :destroy
    has_many :alert_log_entries, as: :alertable, dependent: :destroy, class_name: OneTimeAlertLogEntry

    after_save :process_linked_attachments

    # Allow new instances to start up (prior to migrations run will not have histories or item change subscriptions tables)
    if ActiveRecord::Base.connection.table_exists?('histories') && History.column_names.include?(self.name.foreign_key)
      has_many :histories, dependent: :destroy
    end

    if ActiveRecord::Base.connection.table_exists?('item_change_subscriptions') && ItemChangeSubscription.column_names.include?(self.name.foreign_key)
      has_many :item_change_subscriptions, dependent: :destroy
    end

    scope :need_sync, -> (trading_partner) { joins(need_sync_join_clause(trading_partner)).where(need_sync_where_clause()) }
  end

  def core_module
    CoreModule.find_by_object self
  end

  def label
    cm = self.core_module
    uid = cm.unique_id_field.process_export(self, nil)
    "#{cm.label} #{uid}"
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
    if include_private
      results = self.business_validation_results
    else
      results = self.business_validation_results.public_rule
    end
    results.each do |bvr|
      r = BusinessValidationResult.worst_state r, bvr.state
    end
    r
  end

  def business_rules state, include_private:true
    results = self.business_validation_results.
      joins(:business_validation_template).
      joins(business_validation_rule_results: [:business_validation_rule]).
      where(business_validation_rule_results: {state: state})

    if !include_private
      results = results.where({business_validation_templates: {private: [nil, false]}})
    end

    results.uniq.
      order("business_validation_rules.name").
      pluck("business_validation_rules.name")
  end

  def business_rule_templates state, include_private:true
    results = self.business_validation_results.
      joins(:business_validation_template).
      where(business_validation_results: {state: state})

    if !include_private
      results = results.where({business_validation_templates: {private: [nil, false]}})
    end

    results.uniq.
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
    self.attachments.map {|a| a.attachment_type.presence || nil }.compact.uniq.sort
  end

  def attachment_filenames
    self.attachments.map {|a| a.attached_file_name.presence || nil }.compact.uniq.sort
  end

  # method for selecting a type of attachment such as "application/pdf"
  def options_for_attachments_select content_types
    content_types = Array.wrap(content_types)

    attachments = []

    self.attachments.each do |a|
      if content_types.blank? || content_types.include?(a.attached_content_type)
        descriptor = a.attachment_type.blank? ? a.attached_file_name : "#{a.attachment_type} - #{a.attached_file_name}"
        attachments << [descriptor, a.id]
      end
    end

    if attachments.blank?
      return_attachments = [["No appopriate attachments exist.", "nil"]]
    else
      return_attachments = [["Select an option", "nil"]] + attachments
    end

    return_attachments
  end

  def all_attachments
    r = []
    r += self.attachments.to_a
    self.linkable_attachments.each {|linkable| r << linkable.attachment}
    r.sort do |a, b|
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
    self.attributes.each_key { |att| attrs_to_erase[att] = nil unless att.match(/_id$/) || (skip.member? att) }
    self.assign_attributes(attrs_to_erase, :without_protection => true)
  end

  def process_linked_attachments
    LinkedAttachment.delay(:priority=>600).create_from_attachable_by_class_and_id(self.class, self.id) if !self.dont_process_linked_attachments && LinkableAttachmentImportRule.exists_for_class?(self.class)
  end

  # return link back url for this object (yes, this is a violation of MVC, but we need it for downloaded file links)
  def view_url
    self.class.excel_url self.id
  end

  # return the relative url to the view page for the object
  def relative_url
    self.class.relative_url self.id
  end

  # return an excel friendly link to the object that handles Excel session bugs
  def excel_url
    self.class.excel_url self.id
  end

  # Splits a string into an array based on newline characters it contains within it.  Strips leading whitespace from
  # most internal values, but not trailing whitespace, nor is leading whitespace removed from the first value found.
  def split_newline_values string_containing_newlines
    self.class.split_newline_values string_containing_newlines
  end

  def create_newline_split_field array_containing_values
    self.class.create_newline_split_field array_containing_values
  end

  def find_or_initialize_sync_record trading_partner
    sr = self.sync_records.find { |sr| sr.trading_partner == trading_partner}
    sr = self.sync_records.build(trading_partner: trading_partner) if sr.nil?

    sr
  end

  module ClassMethods
    def find_by_custom_value custom_definition, value
      self.joins(:custom_values).where('custom_values.custom_definition_id = ?', custom_definition.id).where("custom_values.#{custom_definition.data_column} = ?", value).first
    end

    def has_never_been_synced_where_clause
      # This is solely for the cause where we only ever want to sync an object a single time...therefore, we ONLY want to return results that either
      # do not have a sync record or the sync record sent at date is null - sent_date is null is to allow for clearing and manual resends
      "sync_records.id IS NULL OR sync_records.sent_at IS NULL"
    end

    # Deprecated...use join_clause_for_need_sync
    def need_sync_join_clause trading_partner, join_table = self.table_name
      join_clause_for_need_sync(trading_partner, join_table: join_table)
    end

    def join_clause_for_need_sync trading_partner, join_table: self.table_name
      sql = "LEFT OUTER JOIN sync_records ON sync_records.syncable_type = ? and sync_records.syncable_id = #{ActiveRecord::Base.connection.quote_table_name(join_table)}.id and sync_records.trading_partner = ?"
      sanitize_sql_array([sql, name, trading_partner])
    end

    # Deprecated...use where_clause_for_need_sync
    def need_sync_where_clause join_table = self.table_name, sent_at_before = nil
      where_clause_for_need_sync(join_table: join_table, sent_at_or_before: sent_at_before)
    end

    def where_clause_for_need_sync join_table: self.table_name, sent_at_or_before: nil
      # sent_at_before is for cases where we don't want to resend product records prior to a certain timeframe OR
      # cases where we're splitting up file sends on product count (batching) and don't want to resend ones we just
      # sent in a previous batch.
      query =
      "(sync_records.id is NULL OR
         (
            (sync_records.sent_at is NULL OR
             sync_records.confirmed_at is NULL OR
             sync_records.sent_at > sync_records.confirmed_at OR
             #{ActiveRecord::Base.connection.quote_table_name(join_table)}.updated_at > sync_records.sent_at
            ) AND
            (sync_records.ignore_updates_before IS NULL OR
             sync_records.ignore_updates_before < #{ActiveRecord::Base.connection.quote_table_name(join_table)}.updated_at)
            "
      if sent_at_or_before.respond_to?(:acts_like_time?) || sent_at_or_before.respond_to?(:acts_like_date?)
        query += " AND
            (sync_records.sent_at IS NULL OR sync_records.sent_at < ? OR #{ActiveRecord::Base.connection.quote_table_name(join_table)}.updated_at > sync_records.sent_at)"
        query = ActiveRecord::Base.sanitize_sql_array([query, sent_at_or_before])
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

    def split_newline_values string_containing_newlines
      string_containing_newlines.blank? ? [] : (string_containing_newlines.split(/\r?\n */)).reject(&:blank?)
    end

    def create_newline_split_field array_containing_values
      return nil if array_containing_values.nil?

      array_containing_values.join("\n ")
    end
  end
end
