class AddEditUnfiledEmailsPermissionToUser < ActiveRecord::Migration
  def change
    add_column :users, :unfiled_emails_edit, :boolean
  end
end
