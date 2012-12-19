class AddSubtitleToSurveyResponse < ActiveRecord::Migration
  def self.up
    add_column :survey_responses, :subtitle, :string
  end

  def self.down
    remove_column :survey_responses, :subtitle
  end
end
