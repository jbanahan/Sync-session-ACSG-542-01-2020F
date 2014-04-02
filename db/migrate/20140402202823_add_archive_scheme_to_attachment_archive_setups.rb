class AddArchiveSchemeToAttachmentArchiveSetups < ActiveRecord::Migration
  def change
    add_column :attachment_archive_setups, :archive_scheme, :string
  end
end
