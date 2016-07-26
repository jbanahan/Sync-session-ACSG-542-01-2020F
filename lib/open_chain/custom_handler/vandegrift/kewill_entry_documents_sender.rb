 require 'open_chain/google_drive'

module OpenChain; module CustomHandler; module Vandegrift; class KewillEntryDocumentsSender
  extend OpenChain::FtpFileSupport

  def self.send_google_drive_document_to_kewill account, path, base_folder: "US Entry Documents"
    # The imaging client is only sending the path relative to the folder that's being monitored..
    # we know that's going to be US Entry Documents, so fill it in.
    actual_drive_path = Pathname.new(base_folder).join path

    Lock.acquire("#{account}-#{path}") do 
      drive_client.download_to_tempfile(account, actual_drive_path.to_s) do |file|
        file_info = validate_file(path)
        
        if file_info[:errors].blank?
          # All's good...ftp this file to kewill imaging
          kewill_filename = "I_IE_#{file_info[:entry_number]}__#{file_info[:document_code]}__N_.#{file_info[:extension]}"
          ftp_file file, connect_vfitrack_net("to_ecs/kewill_imaging", kewill_filename)
        else
          # Someone sent us a bad file name...send them back the file letting them know there was a problem.
          # Use google drive to found out who owns the file, and email them back at that address.
          email_to = drive_client.get_file_owner_email(account, actual_drive_path.to_s)
          # If we can't find the owner, use the bug email address (not sure why we wouldn't be able to - unless there's a race condition)
          email_to = OpenMailer::BUG_EMAIL if email_to.blank?
          OpenMailer.send_kewill_imaging_error(email_to, file_info[:errors], File.basename(path), file).deliver!
        end

        drive_client.delete account, actual_drive_path.to_s
      end
    end
  rescue OpenChain::GoogleDrive::FileNotFoundError => e
    # We don't really care here if the file wasn't on drive, there's going to be cases where the client is going to notify us
    # multiple times about the same file in Drive, especially in cases where the job queue is slightly 
    # behind...just swallow the not found error.
  end

  def self.validate_file file_path
    path = Pathname.new file_path
    filename = File.basename file_path
    file_info = validate_filename filename 
    attachment_type = path.parent.basename.to_s
    doc_code = document_code attachment_type

    if doc_code.blank?
      file_info[:errors] << "No Kewill Imaging document code is configured for #{attachment_type}." if doc_code.nil?
    else
      file_info[:document_code] = doc_code
    end

    file_info
  end
  private_class_method :validate_file

  def self.validate_filename filename
    matches = filename.scan(/\A(\d+)\s*[-_]\s*(.*)\.([^.]+)\z/i).first
    value = {errors: []}
    if matches.try(:length) == 3
      value[:entry_number] = matches[0].to_s.strip
      value[:customer_number] = matches[1].to_s.strip
      value[:extension] = matches[2].to_s.strip

      if !["pdf", "tif"].include? value[:extension].to_s.downcase 
        value[:errors] << "Kewill Imaging does not accept '#{value[:extension]}' file types."
      end

      entry = Entry.where(customer_number: value[:customer_number], broker_reference: value[:entry_number], source_system: Entry::KEWILL_SOURCE_SYSTEM).first
      if entry.nil?
        value[:errors] << "No entry found for File # #{value[:entry_number]} under Customer account #{value[:customer_number]}."
      end

    else
      value[:errors] << "Kewill Imaging files must be named with the File #, a hyphen, the file's customer number and then .pdf/.tif.  (ex. '1234 - CUST.pdf')"
    end

    value
  end
  private_class_method :validate_filename

  def self.document_code attachment_type
    AttachmentType.where(name: attachment_type).first.try(:kewill_document_code)
  end
  private_class_method :document_code

  def self.drive_client
    OpenChain::GoogleDrive
  end
  private_class_method :drive_client

end; end; end; end