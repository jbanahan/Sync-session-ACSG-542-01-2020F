class AttachmentArchiveSetup < ActiveRecord::Base
  attr_accessible :company_id, :start_date

  belongs_to :company

  #creates an archive with files for this importer that are on entries up to the max_size_in_bytes size
  def create_entry_archive! name, max_size_in_bytes
    archive = nil
    AttachmentArchiveSetup.transaction do
      archive = AttachmentArchive.create! :name=>name, :start_at=>Time.now, :company_id=>self.company_id 
      running_size = 0
      available_entry_files.each do |att|
        running_size += att.attached_file_size
        break if running_size > max_size_in_bytes
        archive.attachment_archives_attachments.create!(:attachment_id=>att.id,:file_name=>att.unique_file_name)
      end
    end
    archive
  end

  #are there any more entry attachments available to be put on archives
  def entry_attachments_available?
    entry_attachments_available_count > 0
  end

  def entry_attachments_available_count
    available_entry_files.count
  end

  private
  def available_entry_files
    days_ago = Time.current.midnight - 30.days
    Attachment.select("distinct attachments.*").
      joins("INNER JOIN entries on entries.id = attachments.attachable_id AND attachments.attachable_type = \"Entry\"").
      joins("INNER JOIN broker_invoices ON entries.id = broker_invoices.entry_id").
      joins("LEFT OUTER JOIN attachment_archives_attachments on attachments.id = attachment_archives_attachments.attachment_id").
      where("attachment_archives_attachments.attachment_id is null").
      where("broker_invoices.invoice_date <= ?", days_ago).
      where("broker_invoices.invoice_date >= ?",self.start_date).
      where("entries.importer_id = ?",self.company_id).
      order("entries.arrival_date ASC")
  end
end
