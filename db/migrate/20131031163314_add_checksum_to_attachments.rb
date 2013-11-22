class AddChecksumToAttachments < ActiveRecord::Migration
  def change
    add_column :attachments, :checksum, :string
  end
end
