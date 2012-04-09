class CreateSupportTicketComments < ActiveRecord::Migration
  def self.up
    create_table :support_ticket_comments do |t|
      t.integer :support_ticket_id
      t.integer :user_id
      t.text :body

      t.timestamps
    end
    add_index :support_ticket_comments, :support_ticket_id
  end

  def self.down
    drop_table :support_ticket_comments
  end
end
