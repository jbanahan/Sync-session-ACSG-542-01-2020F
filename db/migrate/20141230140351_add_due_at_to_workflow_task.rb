class AddDueAtToWorkflowTask < ActiveRecord::Migration
  def change
    add_column :workflow_tasks, :due_at, :datetime
    add_index :workflow_tasks, :due_at
  end
end
