class AddKewillDocumentCodeToAttachmentTypes < ActiveRecord::Migration
  def change
    add_column :attachment_types, :kewill_document_code, :string
  end
end
