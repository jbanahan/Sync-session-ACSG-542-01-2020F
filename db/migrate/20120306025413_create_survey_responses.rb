class CreateSurveyResponses < ActiveRecord::Migration
  def self.up
    create_table :survey_responses do |t|
      t.integer :survey_id
      t.integer :user_id
      t.datetime :email_sent_date
      t.datetime :email_opened_date
      t.datetime :response_opened_date
      t.datetime :submitted_date
      t.datetime :accepted_date

      t.timestamps
    end
    add_index :survey_responses, :survey_id
    add_index :survey_responses, :user_id
  end

  def self.down
    drop_table :survey_responses
  end
end
