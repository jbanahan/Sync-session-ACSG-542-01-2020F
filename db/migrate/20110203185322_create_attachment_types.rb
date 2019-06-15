class CreateAttachmentTypes < ActiveRecord::Migration
  def self.up
    create_table :attachment_types do |t|
      t.string :name
      t.string :module_type

      t.timestamps null: false
    end
  end

  def self.down
    drop_table :attachment_types
  end
end
