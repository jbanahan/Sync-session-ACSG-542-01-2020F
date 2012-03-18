class CreateAnswers < ActiveRecord::Migration
  def self.up
    create_table :answers do |t|
      t.integer :survey_response_id
      t.integer :question_id
      t.string :choice
      t.string :rating

      t.timestamps
    end
    add_index :answers, :survey_response_id
    add_index :answers, :question_id
  end

  def self.down
    drop_table :answers
  end
end
