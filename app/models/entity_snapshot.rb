# == Schema Information
#
# Table name: entity_snapshots
#
#  bucket              :string(255)
#  bulk_process_log_id :integer
#  change_record_id    :integer
#  compared_at         :datetime
#  context             :string(255)
#  created_at          :datetime         not null
#  doc_path            :string(255)
#  id                  :integer          not null, primary key
#  imported_file_id    :integer
#  recordable_id       :integer
#  recordable_type     :string(255)
#  snapshot            :text(65535)
#  updated_at          :datetime         not null
#  user_id             :integer
#  version             :string(255)
#
# Indexes
#
#  Uncompared Items                                             (bucket,doc_path,compared_at)
#  index_entity_snapshots_on_bulk_process_log_id                (bulk_process_log_id)
#  index_entity_snapshots_on_change_record_id                   (change_record_id)
#  index_entity_snapshots_on_imported_file_id                   (imported_file_id)
#  index_entity_snapshots_on_recordable_id_and_recordable_type  (recordable_id,recordable_type)
#  index_entity_snapshots_on_user_id                            (user_id)
#

require 'open_chain/s3'
require 'open_chain/entity_compare/entity_comparator'
class EntitySnapshot < ActiveRecord::Base
  include SnapshotS3Support

  attr_accessible :bucket, :bulk_process_log_id, :change_record_id, 
    :compared_at, :context, :doc_path, :imported_file_id, :imported_file, 
    :recordable_id, :recordable_type, :snapshot, :user_id, :user, :version, 
    :recordable, :created_at

  cattr_accessor :snapshot_writer_impl

  belongs_to :recordable, polymorphic: true, inverse_of: :entity_snapshots
  belongs_to :user
  belongs_to :imported_file
  belongs_to :change_record, :inverse_of => :entity_snapshot
  belongs_to :bulk_process_log

  validates :recordable, :presence => true
  validates :user, :presence => true

  after_destroy :delete_from_s3

  class DefaultSnapshotWriterImpl
    def self.entity_json entity
      # In order to ensure that entity snapshots contain up-to-date data about business rules
      # we're always going to run business rules prior to generating the snapshot.  This ensures
      # that ALL snapshots always contain the current business rule states in them and the comparators
      # can operate under the assumption that the rule states in the snapshot they're processing
      # are current to the snapshot state.  

      # In essense, what this ensure is that there's not a moment in time where the actual data for the snapshot
      # may be failing business rules, but because the business rules haven't been run yet by an asynchronous process, 
      # the state of the rules aren't correctly reflected in the snapshot.
      run_business_rules(entity)

      cm = CoreModule.find_by_class_name entity.class.to_s
      raise "CoreModule could not be found for class #{entity.class.to_s}." if cm.nil?
      cm.entity_json(entity)
    end

    def self.run_business_rules entity
      # Disable snapshot'ing the entity since we're literally going to snapshot that same entity in about 2 lines of code anyway.
      BusinessValidationTemplate.create_results_for_object! entity, snapshot_entity: false
    end
  end

  def self.snapshot_writer
    # This is primarily here so that our test cases can swap in a null writer implementation.
    impl = snapshot_writer_impl
    if impl.nil?
      impl = DefaultSnapshotWriterImpl
    end

    impl
  end

  # This is the main method for creating snapshots
  def self.create_from_entity entity, user=User.current, imported_file=nil, context=nil
    json = snapshot_writer.entity_json(entity)
    es = EntitySnapshot.create!(:recordable=>entity,:user=>user,:imported_file=>imported_file,:context=>context)

    # If storing the snapshot failed, then we shouldn't be trying to process it...this will be handled
    # later when the snapshot is restored.
    if store_snapshot_json(es, json)
      OpenChain::EntityCompare::EntityComparator.handle_snapshot es
    end

    MasterSetup.config_true?(:write_snapshot_caller) do 
      write_snapshot_caller(es)
    end
    
    es
  end

  def self.store_snapshot_json es, json, record_failure: true
    success = false
    begin
      es.write_s3 json
      es.save!
      success = true
    rescue Exception => e
      # If we fail to write the snapshot to S3, buffer the data in the database and then 
      # another service will come along and process it, push it to s3 and then relink the s3 data to the
      # snapshot.
      EntitySnapshotFailure.create!(snapshot: es, snapshot_json: json) if record_failure
    end

    success
  end

  def self.write_snapshot_caller es
    bucket_name = "#{Rails.env}.#{MasterSetup.get.system_code}.snapshot_callers.vfitrack.net"
    OpenChain::S3.create_bucket!(bucket_name, versioning: false) unless OpenChain::S3.bucket_exists?(bucket_name)
    OpenChain::S3.upload_data(bucket_name,"#{es.recordable_type}/#{es.id}.txt",caller.join("\n"))
  rescue Exception => e
    e.log_me
  end

  def snapshot_json as_string = false
    json_text = nil
    # If we haven't persisted the snapshot and written the doc_path for it, then
    # there's no snapshot data yet..return nil
    if self.snapshot.nil? && !self.doc_path.blank?
      json_text = self.class.retrieve_snapshot_data_from_s3(self)
    else
      json_text = self.snapshot
    end

    return nil if json_text.blank?
    as_string ? json_text : ActiveSupport::JSON.decode(json_text)
  end

  # more clearly named version of snapshot_json
  def snapshot_hash
    snapshot_json false
  end

  def restore user
    o = recursive_restore snapshot_json, user
    o.create_snapshot user
    o
  end

  #finds the previous snapshot for the same recordable object
  def previous
    EntitySnapshot.where(:recordable_type=>self.recordable.class,:recordable_id=>self.recordable).where("entity_snapshots.id < ?",self.id).order("entity_snapshots.id DESC").first
  end

  #returns the diff between this snapshot and the one immediately previous to it for the same recordable object
  #if this is the first snapshot, then it runs a diff vs an empty snapshot
  def diff_vs_previous
    p = self.previous
    p = EntitySnapshot.new(:recordable=>self.recordable) if p.nil?
    diff p
  end

  def diff older_snapshot
    my_json = self.snapshot_json
    old_json = older_snapshot.snapshot_json
    diff_json old_json, my_json
  end

  def s3_integration_file_context?
    (self.context.to_s =~ /\A\d{4}-\d{2}\/\d{2}\//).present?
  end

  def cleansed_context
    if s3_integration_file_context?
      File.basename(self.context.to_s)
    else
      self.context.to_s
    end
  end

  def s3_integration_file_context_download_link
    s3_integration_file_context? ? OpenChain::S3.url_for(OpenChain::S3.integration_bucket_name, self.context) : ""
  end

  def snapshot_download_link
    OpenChain::S3.url_for(self.bucket, self.doc_path, 1.minute, version: self.version)
  end

  ###################################
  # S3 Handling Stuff
  ###################################

  def expected_s3_path
    self.class.s3_path self.recordable
  end

  def write_s3 json
    data = self.class.write_to_s3 json, self.recordable
    self.bucket = data[:bucket]
    self.doc_path = data[:key]
    self.version = data[:version]
  end

  ##################################
  # End S3 handling stuff
  ##################################
  private

  def recursive_restore obj_hash, user, parent = nil
    # unwrap the outer hash
    if obj_hash['entity']
      obj_hash = obj_hash['entity']
    end

    core_module = CoreModule.find_by_class_name obj_hash['core_module']
    obj = core_module.klass.find_by_id obj_hash['record_id']
    obj = core_module.klass.new unless obj
    custom_values = []
    @cm_cache ||= Hash.new do |h, k|
      h[k] = k.model_fields_for_snapshot(include_non_restore_fields: false).values
    end

    if !obj.respond_to?(:can_edit?) || obj.can_edit?(user)
      @cm_cache[core_module].each do |mf|
        v = obj_hash['model_fields'][mf.uid]
        v = obj_hash['model_fields'][mf.uid.to_s]
        v = "" if v.nil?
        if mf.custom?
          cv = CustomValue.new(custom_definition: mf.custom_definition)
          cv.value = v
          custom_values << cv
        else
          mf.process_import obj, v, user, bypass_user_check: true
        end
      end
      obj_hash['model_fields'].each do |mfuid,val|
        #this loop writes the values in the hash again.
        #this prevents an empty value not in the hash from blanking something
        #that is in the hash like a missing Country ISO blanking an included Country Name
        mf = ModelField.find_by_uid mfuid
        mf.process_import(obj, val, user, bypass_user_check: true) unless mf.blank? || mf.custom?
      end
      obj.last_updated_by_id=user.id if obj.respond_to?(:last_updated_by_id=)

      #first we clear out any children that shouldn't be there so we don't have validation conflicts
      good_children = {}
      if obj_hash['children']
        obj_hash['children'].each do |c|
          c_hash = c['entity']
          # No need to weed out records we know won't have an id to delete
          next if c_hash['record_id'].blank?

          child_core_module = CoreModule.find_by_class_name c_hash['core_module']
          good_children[child_core_module] ||= [0]
          good_children[child_core_module] << c_hash['record_id']
        end
      end
      default_child = core_module.default_module_chain.child(core_module) #make we get the default child if it wasn't found in the hash
      if default_child
        if default_child.length == 1
          good_children[default_child[0]] ||= [0]
        else
          raise "Recursive restore cannot be used with modules that contain sibling modules."
        end
      end

      good_children.each do |cm,good_ids|
        l = core_module.child_lambdas[cm]
        l.call(obj).where("NOT #{cm.table_name}.id IN (?)",good_ids).destroy_all if l
      end

      # Then we create/update children based on hash

      # Skipping children without record_ids is primarily a workaround for buggy snapshot records...not exactly sure at the moment
      # why we appear to be getting child entity records with null record ids that appear to be
      # duplicate records. .ie two classification records for same country, one without a record id.
      obj_hash['children'].each {|c| recursive_restore(c['entity'], user, obj) unless c['entity']['record_id'].blank?} if obj_hash['children']
    end
    obj.save!
    unless custom_values.empty?
      custom_values.each {|cv| cv.customizable = obj}
      CustomValue.batch_write! custom_values
    end
    if parent
      parent_core_module = CoreModule.find_by_object parent
      c_lam = parent_core_module.child_lambdas[core_module]
      c_lam.call(parent) << obj if c_lam
    end
    obj
  end
  def diff_json old_json, new_json
    d = ESDiff.new
    d.record_id = new_json.nil? ? old_json['entity']['record_id'] : new_json['entity']['record_id']
    d.core_module = new_json.nil? ? old_json['entity']['core_module'] : new_json['entity']['core_module']
    cm = CoreModule.find_by_class_name d.core_module
    d.model_fields_changed = model_field_diff(old_json,new_json)

    new_children = Array.wrap(new_json.try(:[], 'entity').try(:[], 'children'))
    old_children = Array.wrap(old_json.try(:[], 'entity').try(:[], 'children'))

    new_children.each do |nc|
      oc = old_children.nil? ? nil : find_matching_child(old_children, nc)
      # If the new child was also found in the old child list, that means it wasn't added or deleted
      if oc
        d.children_in_both << diff_json(oc, nc)
      else
        # Since the child wasn't found in the old children, then it must be new
        d.children_added << diff_json(nil, nc)
      end
    end

    # Now identify which potential child objects got deleted between the old and new snapshot
    old_children.each do |oc|
      new_child = find_matching_child(new_children, oc)
      # If the old child wasn't found in the list of new children, then we have a case where the child object was deleted
      if new_child.nil?
        d.children_deleted << diff_json(oc,nil)
      end
    end

    d
  end


  def find_matching_child container, target
    container.each do |c|
      next unless c['entity']['core_module']==target['entity']['core_module']
      if c['entity']['record_id']==target['entity']['record_id']
        return c
      else
        cm = CoreModule.find_by_class_name(target['entity']['core_module'])
        cm.key_model_field_uids.each do |uid|
          t_val = target['entity']['model_fields'][uid.to_s]
          c_val = c['entity']['model_fields'][uid.to_s]
          return c if !t_val.blank? && t_val == c_val
        end
      end
    end
    nil
  end

  def model_field_diff old_json, new_json
    r = {}
    new_mf = new_json.nil? ? {} : new_json['entity']['model_fields']
    old_mf = old_json.nil? ? {} : old_json['entity']['model_fields']
    
    parse_diff_datetimes(new_mf)
    parse_diff_datetimes(old_mf)

    # Diff here is an activerecord hash method which uses == to determine equality
    fields_changed = hash_diff(new_mf, old_mf).keys
    fields_changed.each do |mf_uid|
      # Don't show values as different if they're both blank .ie if one is nil and the other is "" don't log that as a change.
      # This is because the diff screen itself skips over any field where they're both blank...so if we don't do this here,
      # the screen sees there are fields in diff's model_fields_changed attribute and shows that the object changed, but
      # then doesn't show any actual changes...so it's confusing to the user.
      r[mf_uid] = [old_mf[mf_uid],new_mf[mf_uid]] unless old_mf[mf_uid].blank? && new_mf[mf_uid].blank?
    end
    r
  end

  def hash_diff h1, h2
    # This is pretty much copied from the ActiveSupport::CoreExtensions::Hash#Diff method that was removed in Rails 4.1
    h1.dup.delete_if { |k, v| h2[k] == v }.merge(h2.dup.delete_if { |k, v| h1.has_key?(k) })
  end

  def parse_diff_datetimes model_field_hash
    # Times are stored as iso 8601 strings in the database, so before we diff the values we want to parse all 
    # times as actual time objects, this will allow the diff to display to the user in their timezone.
    #
    # This also resolves a previous bug in snapshots where the snapshot data was written using the value in Time.zone
    # rather than always forcing it to UTC (which it does as of end of April 2017). ActiveRecord::DateWithTime
    # recognizes that '2017-04-01 12:00:00 UTC' is the same moment as '2017-04-01 08:00:00 -0400' and thus will
    # not flag a field as being changed (as happened when we still evaluated the datetime as a string for the diff)
    date_time_regex = /\A\d{4}-\d{1,2}-\d{1,2}T\d{1,2}:\d{1,2}:\d{1,2}/
    model_field_hash.each_pair do |k, v|
      # Do a quicker upfront approach to determine if we MAY or may not have a date time value (regex is infinitely faster 
      # than looking up the uid).
      if v.is_a?(String) && v =~ date_time_regex
        mf = ModelField.find_by_uid k
        if mf.data_type == :datetime
          date = Time.zone.parse v
          model_field_hash[k] = date unless date.nil?
        end
      end
    end
  end

  class ESDiff
    attr_accessor :record_id, :core_module, :model_fields_changed, :children_in_both, :children_added, :children_deleted
    def initialize
      @children_in_both = []
      @children_added = []
      @children_deleted = []
    end

    def blank?
      return true if nested_blank?(@children_in_both) && nested_blank?(@children_added) && nested_blank?(@children_deleted) && @model_fields_changed.blank?

    end

    def nested_blank? ary
      return ary.blank? if ary.blank?
      ary.each {|a| return false unless a.blank?}
      return true
    end

    def core_module_instance
      CoreModule.find_by_class_name self.core_module
    end

    def record
      return nil if self.record_id.nil?
      cm = self.core_module_instance
      return nil if cm.nil?

      cm.klass.where(id: self.record_id).first
    end
  end
end
