class AddAssignedToIdToWorkflowTask < ActiveRecord::Migration
  def change
    add_column :workflow_tasks, :assigned_to_id, :integer
    add_index :workflow_tasks, :assigned_to_id
  end
end
