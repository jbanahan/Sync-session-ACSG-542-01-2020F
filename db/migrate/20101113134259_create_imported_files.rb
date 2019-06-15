class CreateImportedFiles < ActiveRecord::Migration
  def self.up
    create_table :imported_files do |t|
      t.string :filename
      t.integer :size
      t.string :content_type
      t.integer :import_config_id

      t.timestamps null: false
    end
  end

  def self.down
    drop_table :imported_files
  end
end
