class AddTargetObjectToWorkflowTask < ActiveRecord::Migration
  def change
    add_column :workflow_tasks, :target_object_id, :integer
    add_column :workflow_tasks, :target_object_type, :string
    add_index :workflow_tasks, [:target_object_id,:target_object_type]
  end
end
