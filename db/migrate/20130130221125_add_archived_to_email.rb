class AddArchivedToEmail < ActiveRecord::Migration
  def change
    add_column :emails, :archived, :boolean
    add_index :emails, :archived
  end
end
