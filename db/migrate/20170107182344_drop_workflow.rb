class DropWorkflow < ActiveRecord::Migration
  def up
    drop_table :workflow_processor_runs
    drop_table :multi_state_workflow_tasks
    drop_table :workflow_tasks
    drop_table :workflow_instances
    execute "DELETE FROM schedulable_jobs WHERE run_class IN ('OpenChain::DailyTaskEmailJob','OpenChain::WorkflowProcessor')"
    remove_column :master_setups, :workflow_classes
  end

  def down
  end
end
