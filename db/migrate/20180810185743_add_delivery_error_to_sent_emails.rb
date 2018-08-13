class AddDeliveryErrorToSentEmails < ActiveRecord::Migration
  def change
    add_column :sent_emails, :delivery_error, :text
  end
end
