class RemoveDisplayRankFromWorkflowTask < ActiveRecord::Migration
  def up
    remove_column :workflow_tasks, :display_rank
  end

  def down
    add_column :workflow_tasks, :display_rank, :integer
  end
end
