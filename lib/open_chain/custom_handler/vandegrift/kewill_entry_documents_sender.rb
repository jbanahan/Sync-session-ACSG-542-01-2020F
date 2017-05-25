require 'open_chain/google_drive'
require 'open_chain/s3'

module OpenChain; module CustomHandler; module Vandegrift; class KewillEntryDocumentsSender
  extend OpenChain::FtpFileSupport


  def self.run_schedulable opts = {}
    buckets = opts['bucket']
    raise "A 'bucket' option value must be set." if buckets.blank?
    monitor_buckets Array.wrap(buckets)
  end

  def self.monitor_buckets buckets
    buckets.each do |bucket|
      OpenChain::S3.each_file_in_bucket(bucket) do |key, version|
        self.delay.send_s3_document_to_kewill(bucket, key, version)
      end
    end
  end

  def self.send_s3_document_to_kewill bucket, key, version
    Lock.acquire("#{bucket}-#{key}-#{version}") do
      OpenChain::S3.download_to_tempfile(bucket, key, version: version, original_filename: File.basename(key)) do |file|
        file_info = validate_file(key, file)

        if file_info[:errors].blank?
          # All's good...ftp this file to kewill imaging...use the current timestamp as the comment field so that any files that would be named
          # the same go through w/ unique filenames due to the timestamp portion of the filename
          with_suffix_value(file_info[:entry], file_info[:attachment_type_obj]) do |suffix|
            kewill_filename = "I_IE_#{file_info[:entry_number]}__#{file_info[:document_code]}_#{suffix}_N_#{Time.zone.now.to_f.to_s.gsub(".", "-")}.#{file_info[:extension]}"
            ftp_file file, connect_vfitrack_net("to_ecs/kewill_imaging", kewill_filename)
          end
          
        else
          # Use custom metadata sent by the imaging client to identify the email address of the file's owner.
          email_to = OpenChain::S3.metadata("owner", bucket, key, version)

          # If we can't find the owner, use the bug email address (not sure why we wouldn't be able to unless something's up with the imaging client
          #  or possibly google drive - where the client fetches the owner email from)
          email_to = OpenMailer::BUG_EMAIL if email_to.blank?

          # Don't attach the email if it's too large...no point in trying to send a 70MB file.
          OpenMailer.send_kewill_imaging_error(email_to, file_info[:errors], file_info[:attachment_type], file.original_filename, file_info[:too_large] ? nil : file).deliver!
        end
      end

      OpenChain::S3.delete bucket, key, version
    end
  rescue OpenChain::S3::NoSuchKeyError => e
    # We don't care if the key is no longer present....it means there were multiple processes vying for the file and ours lost.
    # That's fine.
    nil
  end

  def self.validate_file file_path, file
    path = Pathname.new file_path
    filename = File.basename file_path
    file_info = validate_filename filename 
    attachment_type = path.parent.basename.to_s
    file_info[:attachment_type] = attachment_type
    file_info[:attachment_type_obj] = document_type(attachment_type)

    doc_code = file_info[:attachment_type_obj].try(:kewill_document_code)

    if doc_code.blank?
      file_info[:errors] << "No Kewill Imaging document code is configured for '#{attachment_type}'."
    else
      # If the document type does not have a kewill_attachment_type value...then it's been set up wrong...raise an error
      file_info[:errors] << "Attachment Type '#{attachment_type}' is missing a Kewill Attachment Type cross-reference value.  Please forward this error to IT Support." if file_info[:attachment_type_obj].kewill_attachment_type.blank?
      file_info[:document_code] = doc_code
    end

    if file.size > 70.megabytes
      file_info[:errors] << "File is larger than 70 Megabytes.  Please forward this error to IT Support for help loading this file."
      file_info[:too_large] = true
    end

    file_info
  end
  private_class_method :validate_file

  def self.validate_filename filename
    # The filename needs to start with digits representing the file number, then the custoemr number and then the extension.
    # Alternately, we're allowing the users to add information AFTER the customer number.  If a space is present after some letters
    # numbers, we're going to strip everything from the space until the extension.
    matches = filename.scan(/\A(\d+)\s*[-_]\s*(.*)\.([^.]+)\z/i).first
    value = {errors: []}
    if matches.try(:length) == 3
      value[:entry_number] = matches[0].to_s.strip

      # For the customer number...strip everything after the first space
      customer_number = matches[1].to_s.strip
      if customer_number =~ /^(\S*)\s/
        customer_number = $1
      end

      # Windows by default hides filename extensions, so people often don't realize when they're renaming files and they include
      # .pdf at the end of the file, the file's actual name is file.pdf.pdf.  In this case, we can just handle this.
      # It would be an issue if there were legitimately periods in any customer names...but there's not, so we can just keep
      # stripping off extensions on the customer number segment until we don't hae any to strip.
      if customer_number =~ /([^.]+)\./
        customer_number = $1
      end
      
      value[:customer_number] = customer_number
      value[:extension] = matches[2].to_s.strip

      if !["pdf", "tif"].include? value[:extension].to_s.downcase 
        value[:errors] << "Kewill Imaging does not accept '#{value[:extension]}' file types."
      end

      entry = Entry.where(customer_number: value[:customer_number], broker_reference: value[:entry_number], source_system: Entry::KEWILL_SOURCE_SYSTEM).first
      value[:entry] = entry
      if entry.nil?
        value[:errors] << "No entry found for File # '#{value[:entry_number]}' under Customer account '#{value[:customer_number]}'."
      end

    else
      value[:errors] << "Kewill Imaging files must be named with the File #, a hyphen, the file's customer number and then .pdf/.tif.  (ex. '1234 - CUST.pdf')"
    end

    value
  end
  private_class_method :validate_filename

  def self.document_type attachment_type
    AttachmentType.where(name: attachment_type).first
  end
  private_class_method :document_type

  def self.with_suffix_value entry, attachment_type
    if attachment_type.disable_multiple_kewill_docs?
      yield ""
    else
      Lock.acquire("DocCounter-#{entry.broker_reference}") do 
        document_code = attachment_type.kewill_document_code
        # We need a cross reference from drive name to "actual" name of type used by kewill
        existing_entry_suffix = entry.attachments.where(attachment_type: attachment_type.kewill_attachment_type).order("alliance_suffix DESC").first.try(:alliance_suffix).to_i

        item = KeyJsonItem.entry_document_counts(entry.broker_reference).first_or_initialize
        counts = item.data
        counts = {} if counts.blank?
        # The first document suffix always needs to start at 1, as that's what Kewill does too when generating docs internally.
        json_suffix = counts[document_code].to_i + 1
        if json_suffix < existing_entry_suffix
          json_suffix = existing_entry_suffix + 1
        end

        counts[document_code] = json_suffix
        item.data = counts
        # This is inside of a transaction (and a cross process lock), so we should be good to save the value right away and rely on a transaction
        # rollback to undo the setting should any issue occur
        item.save!

        yield json_suffix
      end
    end
  end

end; end; end; end