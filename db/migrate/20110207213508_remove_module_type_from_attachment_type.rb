class RemoveModuleTypeFromAttachmentType < ActiveRecord::Migration
  def self.up
    remove_column :attachment_types, :module_type
  end

  def self.down
    add_column :attachment_types, :module_type, :string
  end
end
