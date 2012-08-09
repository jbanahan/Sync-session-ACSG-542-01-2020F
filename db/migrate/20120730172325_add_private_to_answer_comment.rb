class AddPrivateToAnswerComment < ActiveRecord::Migration
  def self.up
    add_column :answer_comments, :private, :boolean
  end

  def self.down
    remove_column :answer_comments, :private
  end
end
