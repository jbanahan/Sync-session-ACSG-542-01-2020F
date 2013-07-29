class AddUserToSurveyResponseLog < ActiveRecord::Migration
  def change
    add_column :survey_response_logs, :user_id, :integer
    add_index :survey_response_logs, :user_id
  end
end
