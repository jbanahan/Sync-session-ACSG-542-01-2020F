class CreateMailboxes < ActiveRecord::Migration
  def change
    create_table :mailboxes do |t|
      t.string :name
      t.string :email_aliases

      t.timestamps
    end
    add_index :mailboxes, :email_aliases
  end
end
