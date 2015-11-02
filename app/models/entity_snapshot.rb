require 'open_chain/s3'
require 'open_chain/entity_compare/entity_comparator'
class EntitySnapshot < ActiveRecord::Base
  belongs_to :recordable, :polymorphic=>true
  belongs_to :user
  belongs_to :imported_file
  belongs_to :change_record, :inverse_of => :entity_snapshot
  belongs_to :bulk_process_log

  validates :recordable, :presence => true
  validates :user, :presence => true

  # This is the main method for creating snapshots
  def self.create_from_entity entity, user=User.current, imported_file=nil
    cm = CoreModule.find_by_class_name entity.class.to_s
    raise "CoreModule could not be found for class #{entity.class.to_s}." if cm.nil?
    json = cm.entity_json(entity)
    es = EntitySnapshot.new(:recordable=>entity,:user=>user,:snapshot=>json,:imported_file=>imported_file)
    es.write_s3 json
    es.save
    OpenChain::EntityCompare::EntityComparator.delay.process_by_id(es.id)
    es
  end

  def snapshot_json
    return nil if self.snapshot.nil?
    ActiveSupport::JSON.decode self.snapshot
  end
  
  def restore user
    o = recursive_restore JSON.parse(self.snapshot)['entity'], user
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


  ###################################
  # S3 Handling Stuff
  ###################################
  
  #bucket name for storing entity snapshots
  def self.bucket_name env=Rails.env
    r = "#{env}.#{MasterSetup.get.system_code}.snapshots.vfitrack.net"
    raise "Bucket name too long: #{r}" if r.length > 63
    return r
  end

  #find or create the bucket for this system's EntitySnapshots
  def self.create_bucket_if_needed!
    return if OpenChain::S3.bucket_exists?(bucket_name)
    OpenChain::S3.create_bucket!(bucket_name,versioning: true)
  end

  def expected_s3_path
    rec = self.recordable
    mod = CoreModule.find_by_object(rec)
    
    key_base = rec.id
    raise "key_base couldn't be found for record because it hasn't been saved to database. #{rec.to_s}" unless key_base
    key_base = key_base.to_s.strip.gsub(/\W/,'_').downcase

    class_name = mod.class_name.underscore

    return "#{class_name}/#{key_base}.json"

  end

  def write_s3 json
    path = expected_s3_path
    bucket = self.class.bucket_name
    s3obj, ver = OpenChain::S3.upload_data(bucket, path, json)
    self.bucket = s3obj.bucket.name
    self.doc_path = s3obj.key
    # Technically, version can be nil if uploading to an unversioned bucket..
    # If that happens though, then the bucket we're trying to use is set up wrong.
    # Therefore, we this bomb hard if ver is nil
    self.version = ver.version_id
  end

  ##################################
  # End S3 handling stuff
  ##################################



  private

  def recursive_restore obj_hash, user, parent = nil
    core_module = CoreModule.find_by_class_name obj_hash['core_module']
    obj = core_module.klass.find_by_id obj_hash['record_id']
    obj = core_module.klass.new unless obj
    custom_values = []

    if !obj.respond_to?(:can_edit?) || obj.can_edit?(user)
      model_fields = ModelField.find_by_core_module(core_module)
      model_fields.each do |mf|
        v = obj_hash['model_fields'][mf.uid]
        v = obj_hash['model_fields'][mf.uid.to_s]
        v = "" if v.nil?
        if mf.custom?
          cv = CustomValue.new(:custom_definition=>CustomDefinition.find(mf.custom_id))
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
      good_children[default_child] ||= [0] if default_child
      good_children.each do |cm,good_ids|
        core_module.child_lambdas[cm].call(obj).where("NOT #{cm.table_name}.id IN (?)",good_ids).destroy_all
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
      c_lam.call(parent) << obj
    end
    obj
  end
  def diff_json old_json, new_json
    d = ESDiff.new
    d.record_id = new_json.nil? ? old_json['entity']['record_id'] : new_json['entity']['record_id']
    d.core_module = new_json.nil? ? old_json['entity']['core_module'] : new_json['entity']['core_module']
    cm = CoreModule.find_by_class_name d.core_module
    d.model_fields_changed = model_field_diff(old_json,new_json) 

    new_children = new_json.nil? ? [] : new_json['entity']['children']
    old_children = old_json.nil? ? [] : old_json['entity']['children']

    entities_in_new = []
    if new_children
      new_children.each do |nc|
        entities_in_new << "#{nc['entity']['record_id']}-#{nc['entity']['core_module']}"
        cm.key_model_field_uids.each do |uid|
          entities_in_new << "#{uid}-#{nc['entity']['model_fields'][uid.to_s]}"
        end
        oc = old_children.nil? ? nil : find_matching_child(old_children, nc)
        if oc
          d.children_in_both << diff_json(oc, nc)
        else
          d.children_added << diff_json(nil, nc)
        end
      end
    end

    if old_children
      old_children.each do |oc|
        found = entities_in_new.include?("#{oc['entity']['record_id']}-#{oc['entity']['core_module']}")
        cm.key_model_field_uids.each do |uid|
          break if found
          found = entities_in_new.include?("#{uid}-#{oc['entity']['model_fields'][uid.to_s]}")
        end
        d.children_deleted << diff_json(oc,nil) if !found
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
    fields_changed = new_mf.diff(old_mf).keys
    fields_changed.each do |mf_uid|
      r[mf_uid] = [old_mf[mf_uid],new_mf[mf_uid]]
    end
    r
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

    def recordable
      return nil unless self.record_id
      eval "#{self.core_module}.where(:id=>#{self.record_id}).first"
    end
  end
end
