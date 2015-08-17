class AddMfgAddressToAttachmentProcessJob < ActiveRecord::Migration
  def change
    add_column :attachment_process_jobs, :manufacturer_address_id, :integer
  end
end
