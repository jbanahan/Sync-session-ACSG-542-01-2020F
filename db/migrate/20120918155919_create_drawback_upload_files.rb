class CreateDrawbackUploadFiles < ActiveRecord::Migration
  def self.up
    create_table :drawback_upload_files do |t|
      t.string :processor
      t.datetime :start_at
      t.datetime :finish_at

      t.timestamps
    end
    add_index :drawback_upload_files, :processor
  end

  def self.down
    drop_table :drawback_upload_files
  end
end
