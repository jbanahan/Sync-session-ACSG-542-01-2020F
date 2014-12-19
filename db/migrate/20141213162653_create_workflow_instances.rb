class CreateWorkflowInstances < ActiveRecord::Migration
  def change
    create_table :workflow_instances do |t|
      t.string :name
      t.string :workflow_decider_class, null: false
      t.references :base_object, polymorphic: true, null: false

      t.timestamps
    end
    add_index :workflow_instances, [:base_object_id, :base_object_type]
    add_index :workflow_instances, :workflow_decider_class
  end
end
