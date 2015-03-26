class AttachmentArchiveManifest < ActiveRecord::Base
  attr_accessible :company_id, :finish_at, :start_at

  belongs_to :company, :inverse_of=>:attachment_archive_manifests
  has_one :attachment, :as => :attachable, :dependent=>:destroy

  # create the manifest attachment and set the finish_at variable
  def make_manifest! oldest_archive_start_date_to_include=1.year.ago
    f = generate_manifest_tempfile! oldest_archive_start_date_to_include
    att = self.attachment
    att = self.create_attachment unless att
    att.attached = f
    att.save!
    self.update_attributes(:finish_at=>Time.now)
    f.unlink
    return self
  end

  #generates the manifest file but doesn't attach it or set the finish_at variable
  def generate_manifest_tempfile! oldest_archive_start_date_to_include
    wb = XlsMaker.create_workbook 'Archive', ["Archive Name","Archive Date","Broker Reference","Master Bill of Lading", "PO Numbers", "Release Date","Doc Type","Doc Name"]
    sheet = wb.worksheet "Archive"
    cursor = 0
    column_widths = []
    qry = "SELECT attachment_archives.name as \"Name\", attachment_archives.start_at as \"Archive Date\", entries.broker_reference as \"Broker Reference\",
entries.master_bills_of_lading as \"MBOL\",entries.po_numbers as \"PO Numbers\", entries.release_date as \"Release\", attachments.attachment_type as \"DocType\", attachment_archives_attachments.file_name as \"FileName\" 
FROM attachment_archives 
INNER JOIN attachment_archives_attachments ON attachment_archives.id = attachment_archives_attachments.attachment_archive_id 
INNER JOIN attachments on attachment_archives_attachments.attachment_id = attachments.id 
INNER JOIN entries on attachments.attachable_id = entries.id and attachments.attachable_type = \"Entry\"
WHERE attachment_archives.start_at >= \"#{oldest_archive_start_date_to_include.strftime("%Y-%m-%d")}\" 
AND attachment_archives.company_id = #{self.company_id}"
    result = AttachmentArchiveManifest.connection.execute qry
    result.each do |vals|
      XlsMaker.add_body_row sheet, (cursor+=1), vals, column_widths, true
    end
    t = Tempfile.new(["ArchiveManifest",".xls"])
    wb.write t
    t
  end
end
