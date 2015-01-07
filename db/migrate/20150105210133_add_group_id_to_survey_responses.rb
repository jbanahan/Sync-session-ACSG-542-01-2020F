class AddGroupIdToSurveyResponses < ActiveRecord::Migration
  def change
    add_column :survey_responses, :group_id, :integer
  end
end
