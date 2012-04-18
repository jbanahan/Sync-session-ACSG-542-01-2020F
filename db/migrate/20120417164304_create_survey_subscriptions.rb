class CreateSurveySubscriptions < ActiveRecord::Migration
  def self.up
    create_table :survey_subscriptions do |t|
      t.integer :survey_id
      t.integer :user_id

      t.timestamps
    end
  end

  def self.down
    drop_table :survey_subscriptions
  end
end
