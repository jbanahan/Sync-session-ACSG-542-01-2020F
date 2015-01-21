class AddTaskEmailToUser < ActiveRecord::Migration
  def change
    add_column :users, :task_email, :boolean
  end
end
