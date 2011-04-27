class CreateFileImportResults < ActiveRecord::Migration
  def self.up
    create_table :file_import_results do |t|
      t.integer :imported_file_id
      t.datetime :started_at
      t.datetime :finished_at
      t.integer :run_by_id

      t.timestamps
    end
  end

  def self.down
    drop_table :file_import_results
  end
end
