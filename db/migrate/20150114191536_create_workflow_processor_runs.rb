class CreateWorkflowProcessorRuns < ActiveRecord::Migration
  def change
    create_table :workflow_processor_runs do |t|
      t.datetime :finished_at, null: false
      t.references :base_object, polymorphic: true, null: false
    end
    add_index :workflow_processor_runs, [:base_object_id,:base_object_type], name: 'base_object'
  end
end
