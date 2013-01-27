class AddAssignedUserToEmail < ActiveRecord::Migration
  def change
    add_column :emails, :assigned_to_id, :integer
    add_index :emails, :assigned_to_id
  end
end
