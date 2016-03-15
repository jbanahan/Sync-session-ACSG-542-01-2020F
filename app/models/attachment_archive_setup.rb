class AttachmentArchiveSetup < ActiveRecord::Base
  attr_accessible :company_id, :start_date, :combine_attachments, :combined_attachment_order, :archive_scheme, :end_date

  belongs_to :company

  ARCHIVE_SCHEMES ||= [["Invoice Date Prior To 30 Days Ago", "MINUS_30"], ["Invoice Date Prior to This Month", "PREVIOUS_MONTH"]]

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
    days_ago = nil
    case self.archive_scheme
    when "PREVIOUS_MONTH"
      days_ago = (Time.current.midnight.at_beginning_of_month - 1.day).to_date
    else
      days_ago = (Time.current.midnight - 30.days).to_date
    end

    # If the end date is prior to the days ago value (.ie the cutoff) use the end date instead
    if self.end_date && days_ago && self.end_date < days_ago
      days_ago = self.end_date
    end
    
    non_stitchable_attachments = Attachment.stitchable_attachment_extensions.collect {|ext| "attachments.attached_file_name NOT like '%#{ext}'"}.join (" AND ")

    Attachment.select("distinct attachments.*").
      joins("INNER JOIN entries on entries.id = attachments.attachable_id AND attachments.attachable_type = \"Entry\"").
      joins("INNER JOIN broker_invoices ON entries.id = broker_invoices.entry_id").
      joins("LEFT OUTER JOIN attachment_archives_attachments on attachments.id = attachment_archives_attachments.attachment_id").
      # Rather than relying on a join against the archive setup table for a flag, which would mean for any customer that switched off the packet we'd instantly then 
      # have thousands of back images to fill in for archive, What we're doing here is preventing the use of any other documents in cases where the entry has 
      # one of our prepared / stitched Archive Packets already present
      joins("LEFT OUTER JOIN attachments arc_packet ON attachments.attachable_id = arc_packet.attachable_id and arc_packet.attachment_type = '#{Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE}'").
      where("arc_packet.id IS NULL OR arc_packet.id = attachments.id OR (#{non_stitchable_attachments})").
      where("attachment_archives_attachments.attachment_id is null").
      where("broker_invoices.invoice_date <= ?", days_ago).
      where("broker_invoices.invoice_date >= ?",self.start_date).
      where("entries.importer_id = ?",self.company_id).
      where("attachments.is_private IS NULL OR attachments.is_private = 0").
      order("entries.arrival_date ASC")
  end
end
