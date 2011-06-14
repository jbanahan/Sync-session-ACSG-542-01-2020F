class EntitySnapshot < ActiveRecord::Base
  belongs_to :recordable, :polymorphic=>true
  belongs_to :user

  validates :recordable, :presence => true

  def self.create_from_entity entity, user=User.current
    cm = CoreModule.find_by_class_name entity.class.to_s
    raise "CoreModule could not be found for class #{entity.class.to_s}." if cm.nil?
    EntitySnapshot.create(:recordable=>entity,:user=>user,:snapshot=>cm.entity_json(entity))
  end

  def snapshot_json
    return nil if self.snapshot.nil?
    ActiveSupport::JSON.decode self.snapshot
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

  private

  def diff_json old_json, new_json
    d = ESDiff.new
    d.record_id = new_json.nil? ? old_json['entity']['record_id'] : new_json['entity']['record_id']
    d.core_module = new_json.nil? ? old_json['entity']['core_module'] : new_json['entity']['core_module']
    d.model_fields_changed = model_field_diff(old_json,new_json) 

    new_children = new_json.nil? ? [] : new_json['entity']['children']
    old_children = old_json.nil? ? [] : old_json['entity']['children']

    entities_in_new = []

    if new_children
      new_children.each do |nc|
        entities_in_new << "#{nc['entity']['record_id']}-#{nc['entity']['core_module']}"
        oc = find_matching_child old_children, nc
        if oc
          d.children_in_both << diff_json(oc, nc)
        else
          d.children_added << diff_json(nil, nc)
        end
      end
    end

    if old_children
      old_children.each do |oc|
        if !entities_in_new.include?("#{oc['entity']['record_id']}-#{oc['entity']['core_module']}")
          d.children_deleted << diff_json(oc,nil)
        end
      end
    end

    d
  end

  def find_matching_child container, target
    container.each do |c|
      return c if c['entity']['record_id']==target['entity']['record_id'] && c['entity']['core_module']==target['entity']['core_module']
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
      eval "#{self.core_module}.where(:id=>#{self.record_id}).first"
    end
  end
end
