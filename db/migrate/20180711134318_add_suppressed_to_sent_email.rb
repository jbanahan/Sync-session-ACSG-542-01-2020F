class AddSuppressedToSentEmail < ActiveRecord::Migration
  def change
    add_column :sent_emails, :suppressed, :boolean, default: false
  end
end
