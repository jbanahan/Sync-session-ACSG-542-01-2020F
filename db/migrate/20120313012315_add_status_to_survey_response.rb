class AddStatusToSurveyResponse < ActiveRecord::Migration
  def self.up
    add_column :survey_responses, :status, :string
  end

  def self.down
    remove_column :survey_responses, :status
  end
end
