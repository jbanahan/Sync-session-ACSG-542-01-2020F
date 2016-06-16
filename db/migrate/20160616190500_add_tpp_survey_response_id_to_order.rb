class AddTppSurveyResponseIdToOrder < ActiveRecord::Migration
  def change
    add_column :orders, :tpp_survey_response_id, :integer
    add_index :orders, :tpp_survey_response_id
  end
end
