class AddAddressToSurveyResponse < ActiveRecord::Migration
  def self.up
    add_column :survey_responses, :name, :string
    add_column :survey_responses, :address, :text
    add_column :survey_responses, :phone, :string
    add_column :survey_responses, :fax, :string
    add_column :survey_responses, :email, :string
  end

  def self.down
    remove_column :survey_responses, :email
    remove_column :survey_responses, :fax
    remove_column :survey_responses, :phone
    remove_column :survey_responses, :address
    remove_column :survey_responses, :name
  end
end
