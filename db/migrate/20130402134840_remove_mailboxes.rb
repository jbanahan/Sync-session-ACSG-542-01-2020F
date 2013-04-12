class RemoveMailboxes < ActiveRecord::Migration
  def up
    remove_column :users, :unfiled_emails_edit
    drop_table :emails
    drop_table :mailboxes
    drop_table :mailboxes_users
  end

  def down
    raise "No down for this migration"
  end
end
