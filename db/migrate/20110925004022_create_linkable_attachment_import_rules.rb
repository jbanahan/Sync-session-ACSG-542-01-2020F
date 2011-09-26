class CreateLinkableAttachmentImportRules < ActiveRecord::Migration
  def self.up
    create_table :linkable_attachment_import_rules do |t|
      t.string :path
      t.string :model_field_uid

      t.timestamps
    end
  end

  def self.down
    drop_table :linkable_attachment_import_rules
  end
end
