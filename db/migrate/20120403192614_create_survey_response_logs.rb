class CreateSurveyResponseLogs < ActiveRecord::Migration
  def self.up
    create_table :survey_response_logs do |t|
      t.integer :survey_response_id
      t.text :message

      t.timestamps
    end
    add_index :survey_response_logs, :survey_response_id
  end

  def self.down
    drop_table :survey_response_logs
  end
end
