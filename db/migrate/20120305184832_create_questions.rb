class CreateQuestions < ActiveRecord::Migration
  def self.up
    create_table :questions do |t|
      t.integer :survey_id
      t.integer :rank
      t.text :choices
      t.text :content

      t.timestamps
    end
    add_index :questions, :survey_id
  end

  def self.down
    drop_table :questions
  end
end
