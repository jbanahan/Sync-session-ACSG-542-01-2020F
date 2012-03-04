class LinkedAttachment < ActiveRecord::Base

  belongs_to :linkable_attachment
  belongs_to :attachable, :polymorphic => true

  validates :linkable_attachment, :presence => true
  validates :attachable, :presence => true

  # creates new LinkedAttachment objects to join the given LinkableAttachment to existing CoreModule objects
  # that match by the LinkableAttachment's model_field_uid and value
  # Returns any LinkedAttachments that were created or an empty array
  def self.create_from_linkable_attachment a
    r = []
    mf = a.model_field
    return [] unless mf && a.value
    sc = SearchCriterion.new(:operator=>'eq',:model_field_uid=>a.model_field_uid,:value=>a.value)
    cm = mf.core_module
    attachables = sc.apply cm.klass
    attachables = attachables.where("NOT #{cm.table_name}.id IN (SELECT attachable_id FROM linked_attachments WHERE linkable_attachment_id = ? AND attachable_type = ?)", a.id, cm.class_name)
    attachables.each do |att|
      r << LinkedAttachment.create!(:attachable=>att,:linkable_attachment=>a)
    end
    r
  end

  # creates new LinkedAttachment objects to join the given object to existing LinkableAttachments
  # Returns any LinkedAttachments that were created or an empty array
  def self.create_from_attachable a
    r = []
    return r unless a.id > 0 #check to make sure it's in the DB in case the delayed job is fired after a transaction fails
    module_model_field_keys = CoreModule.find_by_object(a).model_fields.keys.collect{|k| k.to_s}
    all_model_fields = (module_model_field_keys & LinkableAttachment.model_field_uids)
    all_model_fields.in_groups_of(10).each do |mfuid_ary|
      field_value_hash = {}
      mfuid_ary.each do |m| 
        unless m.nil?
          v = ModelField.find_by_uid(m).process_export(a,nil,true)
          field_value_hash[m.to_sym] = v if v 
        end
      end
      if !field_value_hash.blank?
        where_clauses = field_value_hash.keys.collect {|k| "(model_field_uid = '#{k}' AND value = :#{k})"}
        where = where_clauses.join("OR")
        found = LinkableAttachment.where(where,field_value_hash).where("NOT id IN (SELECT linkable_attachment_id FROM linked_attachments where attachable_type = ? AND attachable_id = ?)",a.class.to_s,a.id)
        found.each do |la|
          r << LinkedAttachment.create!(:attachable=>a,:linkable_attachment=>la)
        end
      end
    end
    r
  end
end
