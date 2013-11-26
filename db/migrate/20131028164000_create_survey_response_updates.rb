class CreateSurveyResponseUpdates < ActiveRecord::Migration
  def change
    create_table :survey_response_updates do |t|
      t.references :user
      t.references :survey_response

      t.timestamps
    end
    add_index :survey_response_updates, :user_id
    add_index :survey_response_updates, [:survey_response_id,:user_id], unique:true
  end
end
