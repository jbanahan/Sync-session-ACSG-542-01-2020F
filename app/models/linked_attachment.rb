class LinkedAttachment < ActiveRecord::Base

  belongs_to :linkable_attachment
  belongs_to :attachable, :polymorphic => true

  validates :linkable_attachment, :presence => true
  validates :attachable, :presence => true

  def self.create_from_attachable a
    r = []
    module_model_field_keys = CoreModule.find_by_object(a).model_fields.keys.collect{|k| k.to_s}
    all_model_fields = (module_model_field_keys & LinkableAttachment.model_field_uids)
    all_model_fields.in_groups_of(10).each do |mfuid_ary|
      field_value_hash = {}
      mfuid_ary.each do |m| 
        unless m.nil?
          v = ModelField.find_by_uid(m).process_export(a)
          field_value_hash[m.to_sym] = v if v 
        end
      end
      if !field_value_hash.blank?
        where_clauses = field_value_hash.keys.collect {|k| "(model_field_uid = '#{k}' AND value = :#{k})"}
        where = where_clauses.join("OR")
        found = LinkableAttachment.where(where,field_value_hash).where("NOT id IN (SELECT linkable_attachment_id FROM linked_attachments where attachable_type = ? AND attachable_id = ?)",a.class.to_s,a.id)
        found.each do |la|
          r << LinkedAttachment.create(:attachable=>a,:linkable_attachment=>la)
        end
      end
    end
    r
  end
end
