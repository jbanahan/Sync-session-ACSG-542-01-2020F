require 'open_chain/google_drive'
require 'open_chain/s3'

module OpenChain; module CustomHandler; module Vandegrift; class KewillEntryDocumentsSender
  extend OpenChain::FtpFileSupport

  def self.send_s3_document_to_kewill bucket, key, version
    Lock.acquire("#{bucket}-#{key}-#{version}") do
      OpenChain::S3.download_to_tempfile(bucket, key, version: version, original_filename: File.basename(key)) do |file|
        file_info = validate_file(key)

        begin
          if file_info[:errors].blank?
            # All's good...ftp this file to kewill imaging
            kewill_filename = "I_IE_#{file_info[:entry_number]}__#{file_info[:document_code]}__N_.#{file_info[:extension]}"
            ftp_file file, connect_vfitrack_net("to_ecs/kewill_imaging", kewill_filename)
          else
            # Use custom metadata sent by the imaging client to identify the email address of the file's owner.
            email_to = OpenChain::S3.metadata("owner", bucket, key, version)

            # If we can't find the owner, use the bug email address (not sure why we wouldn't be able to unless something's up with the imaging client
            #  or possibly google drive - where the client fetches the owner email from)
            email_to = OpenMailer::BUG_EMAIL if email_to.blank?

            OpenMailer.send_kewill_imaging_error(email_to, file_info[:errors], file.original_filename, file).deliver!
          end
        ensure
          OpenChain::S3.delete bucket, key, version
        end
      end
    end
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

end; end; end; end