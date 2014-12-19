class CreateWorkflowTasks < ActiveRecord::Migration
  def change
    create_table :workflow_tasks do |t|
      t.string :name
      t.string :task_type_code
      t.references :workflow_instance
      t.integer :display_rank
      t.references :group
      t.string :test_class_name
      t.text :payload_json
      t.datetime :passed_at

      t.timestamps
    end
    add_index :workflow_tasks, [:workflow_instance_id, :task_type_code]
    add_index :workflow_tasks, :test_class_name
    add_index :workflow_tasks, :group_id
  end
end
