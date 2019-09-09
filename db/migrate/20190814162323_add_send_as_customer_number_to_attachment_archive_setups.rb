class AddSendAsCustomerNumberToAttachmentArchiveSetups < ActiveRecord::Migration
  def change
    add_column :attachment_archive_setups, :send_as_customer_number, :string
  end
end
