class AddSurveyPermissionsToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :survey_view, :boolean
    add_column :users, :survey_edit, :boolean
  end

  def self.down
    remove_column :users, :survey_edit
    remove_column :users, :survey_view
  end
end
