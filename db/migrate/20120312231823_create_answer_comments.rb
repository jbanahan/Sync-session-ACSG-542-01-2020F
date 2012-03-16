class CreateAnswerComments < ActiveRecord::Migration
  def self.up
    create_table :answer_comments do |t|
      t.integer :answer_id
      t.integer :user_id
      t.text :content

      t.timestamps
    end
    add_index :answer_comments, :answer_id
  end

  def self.down
    drop_table :answer_comments
  end
end
