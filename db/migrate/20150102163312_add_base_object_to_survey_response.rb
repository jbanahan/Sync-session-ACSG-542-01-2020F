class AddBaseObjectToSurveyResponse < ActiveRecord::Migration
  def change
    add_column :survey_responses, :base_object_type, :string
    add_column :survey_responses, :base_object_id, :integer

    add_index :survey_responses, [:base_object_type, :base_object_id]
  end
end
