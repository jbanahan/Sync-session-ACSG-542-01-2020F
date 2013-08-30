class AddArchivedToSurveyResponses < ActiveRecord::Migration
  def change
    add_column :survey_responses, :archived, :boolean
  end
end
