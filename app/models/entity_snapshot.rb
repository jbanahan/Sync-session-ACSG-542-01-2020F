require 'open_chain/s3'
require 'open_chain/entity_compare/entity_comparator'
class EntitySnapshot < ActiveRecord::Base
  include SnapshotS3Support

  belongs_to :recordable, :polymorphic=>true
  belongs_to :user
  belongs_to :imported_file
  belongs_to :change_record, :inverse_of => :entity_snapshot
  belongs_to :bulk_process_log

  validates :recordable, :presence => true
  validates :user, :presence => true

  # This is the main method for creating snapshots
  def self.create_from_entity entity, user=User.current, imported_file=nil, context=nil
    cm = CoreModule.find_by_class_name entity.class.to_s
    raise "CoreModule could not be found for class #{entity.class.to_s}." if cm.nil?
    json = cm.entity_json(entity)
    es = EntitySnapshot.new(:recordable=>entity,:user=>user,:imported_file=>imported_file,:context=>context)
    es.write_s3 json
    es.save
    OpenChain::EntityCompare::EntityComparator.handle_snapshot es
    es
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
      h[k] = k.model_fields {|mf| mf.restore_field? }.values
    end

    if !obj.respond_to?(:can_edit?) || obj.can_edit?(user)
      @cm_cache[core_module].each do |mf|
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
