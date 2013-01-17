class FixAttachmentsContentType < ActiveRecord::Migration
  def up
    # Update content_type for pdfs that have application/x-octet-stream to a valid content type
    execute <<-SQL
      UPDATE attachments
      SET attached_content_type = 'application/pdf'
      WHERE attached_content_type LIKE '%octet-stream%' AND attached_file_name LIKE '%pdf' AND created_at > '2013-01-1' 
    SQL
 
    execute <<-SQL
      UPDATE attachments
      SET attached_content_type = 'image/tiff'
      WHERE attached_content_type LIKE '%octet-stream%' AND attached_file_name LIKE '%tif' AND created_at > '2013-01-1' 
    SQL
  end

  def down
  end
end
