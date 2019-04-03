class AddDocumentUrlToUserManuals < ActiveRecord::Migration
  def change
    add_column :user_manuals, :document_url, :string
  end
end
