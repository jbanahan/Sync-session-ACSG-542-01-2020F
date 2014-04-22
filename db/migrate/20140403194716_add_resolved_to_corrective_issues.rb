class AddResolvedToCorrectiveIssues < ActiveRecord::Migration
  def change
    add_column :corrective_issues, :resolved, :boolean
  end
end
