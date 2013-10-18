class CreateArchivedFiles < ActiveRecord::Migration
  def change
    create_table :archived_files do |t|
      t.string :file_type
      t.string :comment

      t.timestamps
    end
    add_index :archived_files, :file_type
    add_index :archived_files, :created_at
  end
end
