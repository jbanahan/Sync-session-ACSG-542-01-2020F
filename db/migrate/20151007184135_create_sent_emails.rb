class CreateSentEmails < ActiveRecord::Migration
  def self.up
    create_table :sent_emails do |t|
      t.string :email_subject
      t.string :email_to
      t.string :email_cc
      t.string :email_bcc
      t.string :email_from
      t.string :email_reply_to
      t.timestamp :email_date
      t.text :email_body

      t.timestamps null: false
    end
  end

  def self.down
    drop_table :sent_emails
  end
end
