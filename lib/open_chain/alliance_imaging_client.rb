require 'open_chain/sqs'
require 'open_chain/s3'
require 'open_chain/field_logic'
require 'open_chain/delayed_job_extensions'

class OpenChain::AllianceImagingClient
  extend OpenChain::DelayedJobExtensions

  def self.run_schedulable
    # Rather than add error handlers to ensure every call below runs even if the previous fails
    # just delay them all even though this method is more than likely being already run in a delayed job queue

    # Don't delay the consume images job if there's already 2 in the queue...don't want to monopolize the queue with these
    # if we get a large backlog
    if queued_jobs_for_method(self, :consume_images) < 2
      self.delay.consume_images
    end
  end

  def self.delayed_bulk_request_images search_run_id, primary_keys
    # We need to evaluate the search to get the keys BEFORE delaying the request to the backend queue,
    # otherwise, the search may change prior to the job being processed and then the wrong files get requested.
    if search_run_id.to_i != 0
      params = {sr_id: search_run_id}
      OpenChain::BulkUpdateClassification.replace_search_result_key params
      self.delay.bulk_request_images s3_bucket: params[:s3_bucket], s3_key: params[:s3_key]
    else
      self.delay.bulk_request_images primary_keys: primary_keys
    end
  end

  # takes request for either search results or a set of primary keys and requests images for all entries
  # One of primary_keys or the s3 params must be present
  def self.bulk_request_images primary_keys: nil, s3_bucket: nil, s3_key: nil
    OpenChain::CoreModuleProcessor.bulk_objects(CoreModule::ENTRY, primary_keys: primary_keys, primary_key_file_bucket: s3_bucket, primary_key_file_path: s3_key) do |good_count, entry|
      request_images(entry.broker_reference) if entry.source_system=='Alliance'
    end
  end
  
  #not unit tested since it'll all be mocks
  def self.request_images file_number, message_options = {}
    conf = imaging_config
    OpenChain::SQS.send_json conf["sqs_send_queue"], {"file_number"=>file_number, "sqs_queue"=>conf['sqs_receive_queue'], "s3_bucket" => conf['s3_bucket']}, message_options
  end
  
  #not unit tested since it'll all be mocks
  def self.consume_images
    hash = nil
    retry_count = 0
    begin
      user = User.integration
      # visibility timeout indicates how long after the poll message is received the message will become
      # visible again to be re-picked up.  This comes into play if the message errors.  If that happens,
      # the message won't get deleted (as raising from the poll block causes the message to stay in the queue),
      # thus, after 5 minutes the message will get retried.  This allows for transient errors to be 
      # retried after a lengthy wait.
      OpenChain::SQS.poll(imaging_config['sqs_receive_queue'], visibility_timeout: 300) do |hsh|
        # Create a deep_dup of the hash so anything we may do with it doesn't muck upthe 
        # hash if we need to proxy it
        hash = hsh.deep_dup
        bucket = hsh["s3_bucket"]
        key = hsh["s3_key"]
        version = hsh["s3_version"]

        next if bucket.blank? || key.blank?

        opts = {}
        if !version.blank?
          opts[:version] = version
        end

        file = OpenChain::S3.download_to_tempfile bucket, key, opts
        # Due to the possibility of an SQS message getting rerun and how we zero out 
        # files from the staging S3 location below...zero length files are almost certainly files that have gotten requeued
        # somehow. so we should ignore them
        if file.length > 0
          if hsh["source_system"] == Entry::FENIX_SOURCE_SYSTEM && hsh["export_process"] == "sql_proxy"
            process_fenix_nd_image_file file, hsh, user
          else
            response = process_image_file file, hsh, user
            if response && response[:attachment] && response[:entry].try(:source_system) == Entry::FENIX_SOURCE_SYSTEM && hsh["export_process"] == "Canada Google Drive" && MasterSetup.get.custom_feature?("Proxy Fenix Drive Docs")
              proxy_fenix_drive_docs response[:entry], hash
            else
              # File is only zeroed out when proxy_fenix_drive_docs is not run. This is because the file
              # originates from Google Drive and is forwarded to other VFI Track instances. 
              OpenChain::S3.zero_file bucket, key
            end
          end
        end

        hash = nil
      end
    rescue => e
      e.log_me ["Alliance imaging client hash: #{hash.to_json}"]
      
      # retry the poll to continue processing messages even after an error was raised.  The errored message
      # is now invisible for a period of time so it's not blocking the head of the queue
      retry if (retry_count += 1) < 10
    end
  end

  def self.proxy_fenix_drive_docs entry, message_hash
    # The config will have a key for the customer's name if we're proxying docs for them, with a hash as the value..the value has will have a `queue`
    # key and the value will be the SQS queue(s) to push the message on
    conf = proxy_fenix_drive_docs_config[entry.customer_number.to_s.upcase]
    return unless conf && conf['queue']

    Array.wrap(conf['queue']).each do |queue|
      OpenChain::SQS.send_json queue, message_hash
    end

  end

  def self.proxy_fenix_drive_docs_config
    config = MasterSetup.secrets["proxy_fenix_drive_docs"]

    raise "No Fenix Drive Docs proxy configuration found under 'proxy_fenix_drive_docs' key in secrets.yml" if config.blank?
    config
  end

  # The file passed in here must have the correct file extension for content type discovery or
  # it will likely be saved with the wrong content type.  ie. If you're saving a pdf, the file
  # it points to should have a .pdf extension on it.
  def self.process_image_file t, hsh, user
    # If the file_number is not a string, then the lookup below fails to utilize the 
    # database index and ends up doing a table scan (VERY BAD)
    hsh["file_number"] = hsh["file_number"].to_i.to_s

    Attachment.add_original_filename_method t, hsh["file_name"]
    source_system = hsh["source_system"].nil? ? Entry::KEWILL_SOURCE_SYSTEM : hsh["source_system"]

    attachment_type = hsh["doc_desc"]

    delete_previous_file_versions = nil

    # In the VAST majority of cases, the entry is going to be there already, so I don't want to utilize a global lock
    # literally every time we look up the entry...so for the very few cases where the entry isn't present, we'll do a double lookup
    # Create a shell entry record if there wasn't one, so we can actually attach the image.
    if source_system == Entry::FENIX_SOURCE_SYSTEM
      # The Fenix imaging client sends the entry number as "file_number" and not the broker ref
      entry = Entry.where(:entry_number=>hsh['file_number'], :source_system=>source_system).first
      if entry.nil?
        # Use the same lock name as the Fenix parser so we ensure we're not double creating a file
        Lock.acquire(Lock::FENIX_PARSER_LOCK) do 
          entry = Entry.where(:entry_number=>hsh['file_number'], :source_system=>source_system).first_or_create!(:file_logged_date => Time.zone.now)
        end
      end

      # If we have an "Automated" attachment type for fenix files, use the file name to determine what type of document
      # this is, either a B3 or RNS
      if attachment_type && attachment_type.upcase == "AUTOMATED"
        case hsh["file_name"]
          when /_CDC_/i
            attachment_type = "B3"
            delete_previous_file_versions = true
          when /_RNS_/i
            attachment_type = "Customs Release Notice"
            delete_previous_file_versions = true
          when /_recap_/i
            attachment_type = "B3 Recap"
            delete_previous_file_versions = true
        end
      end

    else
      entry = Entry.where(source_system: source_system, broker_reference: hsh["file_number"]).first
      if entry.nil?
        Lock.acquire(Lock::ALLIANCE_PARSER) do 
          # I'm purposefully leaving out the file logged date setting here for Kewill entries...this value comes from an actual field in Kewill, so don't
          # set it.
          entry = Entry.where(source_system: source_system, broker_reference: hsh["file_number"]).first_or_create!
        end
      end
    end

    if entry
      attachment = nil
      Lock.with_lock_retry(entry) do 
        att = entry.attachments.build
        att.attached = t
        att.attachment_type = attachment_type
        att.is_private = attachment_type.upcase.starts_with?("PRIVATE") ? true : false
        unless hsh["suffix"].blank?
          att.alliance_suffix = hsh["suffix"][2,3]
          att.alliance_revision = hsh["suffix"][0,2]
        end
        att.source_system_timestamp = hsh["doc_date"]

        # If we have an alliance_revision number, we need to make sure there's no other attachments out there that have a higher revision number already.
        # This can happen in scenarios where we're pulling in images for entries that haven't been updated in a little while where the message queue 
        # info comes out of order (.ie revision 1 is sent to VFI Track prior to revision 0).  There's no real ordering of the data in Kewill Imaging either
        # so we don't actually get the document lists from them based on the order they're attached as well, so it's very possible the message queue ordering
        # is not ordered correctly by revision

        # We also need to make sure that if there are other files with the same revision/suffix that we are keeping the document with the newest source system timestamp
        if !att.alliance_revision.blank? && !att.alliance_suffix.blank?
          other_attachments = att.attachable.attachments.where(:attachment_type=>att.attachment_type,:alliance_suffix=>att.alliance_suffix).where("alliance_revision >= ?",att.alliance_revision)

          highest_revision = other_attachments.sort_by {|a| a.alliance_revision }.last
          return if highest_revision && highest_revision.alliance_revision > att.alliance_revision

          most_recent = other_attachments.sort_by {|a| a.source_system_timestamp }.last          
          return if most_recent && most_recent.source_system_timestamp && most_recent.source_system_timestamp > att.source_system_timestamp
        end

        att.save!
        
        if !att.alliance_revision.blank? && !att.alliance_suffix.blank?
          att.attachable.attachments.where("NOT attachments.id = ?",att.id).where(:attachment_type=>att.attachment_type,:alliance_suffix=>att.alliance_suffix).where("alliance_revision <= ?",att.alliance_revision).destroy_all
        end

        if delete_previous_file_versions
          att.attachable.attachments.where("NOT attachments.id = ?",att.id).where(:attachment_type=>att.attachment_type).destroy_all
        end

        entry.create_snapshot user, nil, "Imaging"
        attachment = att
      end

      return {entry: entry, attachment: attachment}
    end

    nil
  end

  def self.process_fenix_nd_image_file t, file_data, user
    # Here's the hash data we can expect from the Fenix ND export process
    # {"source_system" => "Fenix", "export_process" => "sql_proxy", "doc_date" => "", "s3_key"=>"path/to/file.txt", "s3_bucket" => "bucket", 
    #   "file_number" => "11981001795105 ", "doc_desc" => "B3", "file_name" => "_11981001795105 _B3_01092015 14.24.42 PM.pdf", "version" => nil, "public" => true}

    # Version appears to not be used at this point in Fenix

    # If the file_number is not a string, then the lookup below fails to utilize the 
    # database index and ends up doing a table scan (VERY BAD)
    file_data["file_number"] = file_data["file_number"].to_i.to_s

    # For some reason, the file_name for B3's starts w/ _, which is dumb...strip leading _'s (just do it on all files..leading underscores are pointless on anything)
    filename = file_data["file_name"].to_s.gsub(/^_+/, "")

    # For some reason some Fenix files are coming over with an underscore at the end of the filename (after the extension)...this is throwing off the
    # paperclip content spoof detector, since the content type of .tif_ is undefined...strip trailing underscores.
    filename = filename.gsub(/_$/, "")


    Attachment.add_original_filename_method t, filename

    entry = nil
    Lock.acquire(Lock::FENIX_PARSER_LOCK, times: 3) do 
      entry = Entry.where(:entry_number=>file_data['file_number'], :source_system=>OpenChain::FenixParser::SOURCE_CODE).first_or_create!(:file_logged_date => Time.zone.now)
    end

    if entry
      attachment = nil
      Lock.with_lock_retry(entry) do 
        att = entry.attachments.build
        att.attached = t
        att.attachment_type = file_data["doc_desc"]
        att.source_system_timestamp = ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse(file_data["doc_date"]) unless file_data["doc_date"].blank?

        if !file_data["public"].to_s.to_boolean
          att.is_private = true
        end

        delete_other_file_algorithm = nil
        case att.attachment_type.to_s.upcase
        when "B3", "B3 RECAP", "RNS", "CARTAGE SLIP"
          delete_other_file_algorithm = :attachment_type
        when "INVOICE"
          delete_other_file_algorithm = :attachment_type_and_filename
        end

        # Before we save this attachment, make sure there's no other attachments that are actually newer than this one...
        # Which could happen since sqs messages are NOT guaranteed to be read back in the order they were placed (they virtually always
        # will be though)
        can_save = true
        if delete_other_file_algorithm
          other_attachments = other_attachments_query(att, delete_other_file_algorithm).where("source_system_timestamp > ?", att.source_system_timestamp).count
          can_save = other_attachments == 0
        end

        if can_save
          att.save!

          if delete_other_file_algorithm
            # Since we now know this attachment is the "latest" and greatest we can delete any others that are of this type
            other_attachments_query(att, delete_other_file_algorithm).where("NOT attachments.id = ?", att.id).destroy_all
          end
          attachment = att
        end

        entry.create_snapshot user, nil, "Imaging"

      end

      return attachment.nil? ? nil : {entry: entry, attachment: attachment}
    end

    nil
  end

  def self.other_attachments_query attachment, replacement_algorithm
    rel = attachment.attachable.attachments.where(:attachment_type=>attachment.attachment_type)
    rel = rel.where(attached_file_name: attachment.attached_file_name) if replacement_algorithm == :attachment_type_and_filename

    rel
  end

  def self.imaging_config
    config = MasterSetup.secrets["kewill_imaging"]
    raise "No Kewill Imaging config set up.  Make sure a 'kewill_imaging' key is configured in secrets.yml." if config.blank?
    config
  end
  private_class_method :imaging_config
end
