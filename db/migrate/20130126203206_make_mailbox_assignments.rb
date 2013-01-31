class MakeMailboxAssignments < ActiveRecord::Migration
  def change
    create_table :mailboxes_users do |t|
      t.integer :mailbox_id
      t.integer :user_id
    end
    add_index :mailboxes_users, :mailbox_id 
    add_index :mailboxes_users, :user_id
  end
end
