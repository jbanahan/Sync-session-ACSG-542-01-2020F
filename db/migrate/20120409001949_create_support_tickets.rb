class CreateSupportTickets < ActiveRecord::Migration
  def self.up
    create_table :support_tickets do |t|
      t.integer :requestor_id
      t.integer :agent_id
      t.string :subject
      t.text :body
      t.text :state
      t.boolean :email_notifications
      t.integer :last_saved_by_id

      t.timestamps
    end
    add_index :support_tickets, :requestor_id
    add_index :support_tickets, :agent_id
  end

  def self.down
    drop_table :support_tickets
  end
end
