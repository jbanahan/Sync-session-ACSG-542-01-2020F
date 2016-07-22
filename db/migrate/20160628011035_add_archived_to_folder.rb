class AddArchivedToFolder < ActiveRecord::Migration
  def change
    add_column :folders, :archived, :boolean
  end
end
