class AddViewPathToWorkflowTask < ActiveRecord::Migration
  def change
    add_column :workflow_tasks, :view_path, :string
  end
end
