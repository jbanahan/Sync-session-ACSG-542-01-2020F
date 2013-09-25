class CreateCorrectiveActionPlans < ActiveRecord::Migration
  def change
    create_table :corrective_action_plans do |t|
      t.references :survey_response
      t.references :created_by
      t.string :status

      t.timestamps
    end
    add_index :corrective_action_plans, :survey_response_id
    add_index :corrective_action_plans, :created_by_id
  end
end
