class FixAttachmentsContentType < ActiveRecord::Migration
  def up
    # Update content_type for pdfs that have application/x-octet-stream to a valid content type
    Attachment.where("attached_content_type LIKE ? AND attached_file_name LIKE ? AND created_at > ?", "%octet-stream%", "%pdf", Date.new(2013, 1, 1)).
                update_all(:attached_content_type => 'application/pdf')

    # Update content_type for tifs that have application/x-octet-stream to a valid content type
    Attachment.where("attached_content_type LIKE ? AND attached_file_name LIKE ? and created_at > ?", "%octet-stream%", "%tif", Date.new(2013, 1, 1)).
                update_all(:attached_content_type => 'image/tiff')
  end

  def down
  end
end
