class CreateMultiStateWorkflowTasks < ActiveRecord::Migration
  def change
    create_table :multi_state_workflow_tasks do |t|
      t.references :workflow_task
      t.string :state
      t.timestamps
    end
    add_index :multi_state_workflow_tasks, :workflow_task_id
  end
end
