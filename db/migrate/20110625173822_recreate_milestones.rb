class RecreateMilestones < ActiveRecord::Migration
  def self.up
    create_table :milestone_plans do |t|
      t.string :name
      t.string :code

      t.timestamps
    end

    create_table :milestone_definitions do |t|
      t.integer :milestone_plan_id
      t.string :model_field_uid
      t.integer :days_after_previous
      t.integer :previous_milestone_definition_id
      t.boolean :final_milestone
      t.integer :custom_definition_id
    end

    add_index :milestone_definitions, :milestone_plan_id

    add_column :piece_sets, :milestone_plan_id, :integer
  end

  def self.down
    remove_column :piece_sets, :milestone_plan_id
    drop_table :milestone_definitions
    drop_table :milestone_plans
  end
end
