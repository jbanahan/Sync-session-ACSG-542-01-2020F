class CreateEmails < ActiveRecord::Migration
  def change
    create_table :emails do |t|
      t.integer :mailbox_id
      t.string :subject
      t.string :from
      t.text :body_text
      t.text :json_content
      t.text :mime_content
      t.references :email_linkable, :polymorphic=>true

      t.timestamps
    end
    add_index :emails, :mailbox_id
    add_index :emails, :created_at #for sorting
    add_index :emails, :from #for sorting
  end
end
