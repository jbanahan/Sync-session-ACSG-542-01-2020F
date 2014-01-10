class AddDriveFolderToProject < ActiveRecord::Migration
  def change
    add_column :projects, :drive_folder, :string
  end
end
