class AddRatingsListToSurvey < ActiveRecord::Migration
  def self.up
    add_column :surveys, :ratings_list, :text
    add_column :survey_responses, :rating, :string
    add_index :survey_responses, :rating
  end

  def self.down
    remove_index :survey_responses, :rating
    remove_column :survey_responses, :rating
    remove_column :surveys, :ratings_list
  end
end
