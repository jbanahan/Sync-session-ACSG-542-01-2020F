class CreateCustomFiles < ActiveRecord::Migration
  def self.up
    create_table :custom_files do |t|
      t.integer :uploaded_by_id
      t.string :file_type
      t.string :attached_content_type
      t.integer :attached_file_size
      t.datetime :attached_updated_at
      t.string :attached_file_name

      t.timestamps
    end
  end

  def self.down
    drop_table :custom_files
  end
end
