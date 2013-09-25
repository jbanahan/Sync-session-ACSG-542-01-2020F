class CreateCorrectiveIssues < ActiveRecord::Migration
  def change
    create_table :corrective_issues do |t|
      t.references :corrective_action_plan
      t.text :description
      t.text :suggested_action
      t.string :action_taken

      t.timestamps
    end
    add_index :corrective_issues, :corrective_action_plan_id
  end
end
