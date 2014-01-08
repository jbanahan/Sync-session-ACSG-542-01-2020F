class AddProjectPermissionsToUser < ActiveRecord::Migration
  def change
    add_column :users, :project_view, :boolean
    add_column :users, :project_edit, :boolean
  end
end
