require 'open_chain/sqs'
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
    
    self.delay.consume_stitch_responses
    self.delay.send_outstanding_stitch_requests
  end

  # takes request for either search results or a set of primary keys and requests images for all entries
  def self.bulk_request_images search_run_id, primary_keys
    OpenChain::CoreModuleProcessor.bulk_objects(CoreModule::ENTRY,search_run_id,primary_keys) do |good_count, entry|
      OpenChain::AllianceImagingClient.request_images entry.broker_reference if entry.source_system=='Alliance'
    end
  end
  
  #not unit tested since it'll all be mocks
  def self.request_images file_number, message_options = {}
    OpenChain::SQS.send_json "https://queue.amazonaws.com/468302385899/alliance-img-req-#{get_env}", {"file_number"=>file_number}, message_options
  end
  
  #not unit tested since it'll all be mocks
  def self.consume_images
    OpenChain::SQS.retrieve_messages_as_hash "https://queue.amazonaws.com/468302385899/alliance-img-doc-#{get_env}" do |hsh|
      t = OpenChain::S3.download_to_tempfile hsh["s3_bucket"], hsh["s3_key"]
      begin
        if hsh["source_system"] == OpenChain::FenixParser::SOURCE_CODE && hsh["export_process"] == "sql_proxy"
          process_fenix_nd_image_file t, hsh
        else
          OpenChain::AllianceImagingClient.process_image_file t, hsh
        end
      rescue => e
        # If there's an error we should catch it, otherwise the message won't get pulled from the message queue
        raise e unless Rails.env.production?
        e.log_me ["Alliance imaging client hash: #{hsh}"], [t]
      end
    end
  end

  # The file passed in here must have the correct file extension for content type discovery or
  # it will likely be saved with the wrong content type.  ie. If you're saving a pdf, the file
  # it points to should have a .pdf extension on it.
  def self.process_image_file t, hsh
    Attachment.add_original_filename_method t
    t.original_filename= hsh["file_name"]
    source_system = hsh["source_system"].nil? ? OpenChain::AllianceParser::SOURCE_CODE : hsh["source_system"]

    attachment_type = hsh["doc_desc"]

    delete_previous_file_versions = nil
    if source_system == OpenChain::FenixParser::SOURCE_CODE
      # The Fenix imaging client sends the entry number as "file_number" and not the broker ref

      # Create a shell entry record if there wasn't one, so we can actually attach the image.
      # We don't do this for Alliance files because Chain initiates the imaging extracts for it, so
      # there's no real valid scenario where an entry doesn't already exist in Chain.

      entry = Entry.where(:entry_number=>hsh['file_number'], :source_system=>source_system).first_or_create!(:file_logged_date => Time.zone.now)

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
      entry = Entry.find_by_broker_reference_and_source_system hsh["file_number"], source_system
    end

    if entry
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
      end
    end
  end

  def self.process_fenix_nd_image_file t, file_data
    # Here's the hash data we can expect from the Fenix ND export process
    # {"source_system" => "Fenix", "export_process" => "sql_proxy", "doc_date" => "", "s3_key"=>"path/to/file.txt", "s3_bucket" => "bucket", 
    #   "file_number" => "11981001795105 ", "doc_desc" => "B3", "file_name" => "_11981001795105 _B3_01092015 14.24.42 PM.pdf", "version" => nil, "public" => true}

    # Version appears to not be used at this point in Fenix

    Attachment.add_original_filename_method t

    # For some reason, the file_name for B3's starts w/ _, which is dumb...strip leading _'s (just do it on all files..leading underscores are pointless on anything)
    t.original_filename = file_data["file_name"].to_s.gsub(/^_+/, "")

    entry = nil
    Lock.acquire(Lock::FENIX_PARSER_LOCK, times: 3) do 
      entry = Entry.where(:entry_number=>file_data['file_number'].to_s.strip, :source_system=>OpenChain::FenixParser::SOURCE_CODE).first_or_create!(:file_logged_date => Time.zone.now)
    end

    if entry
      Lock.with_lock_retry(entry) do 
        att = entry.attachments.build
        att.attached = t
        att.attachment_type = file_data["doc_desc"]
        att.source_system_timestamp = ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse(file_data["doc_date"]) unless file_data["doc_date"].blank?

        if file_data["public"].to_s != "true"
          # A value of true is the only thing that will allow the image to not be private
          att.is_private = true
        end

        delete_other_file_algorithm = nil
        case att.attachment_type.to_s.upcase
        when "B3", "B3 RECAP", "RNS"
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
        end
      end
    end
  end

  def self.other_attachments_query attachment, replacement_algorithm
    rel = attachment.attachable.attachments.where(:attachment_type=>attachment.attachment_type)
    rel = rel.where(attached_file_name: attachment.attached_file_name) if replacement_algorithm == :attachment_type_and_filename

    rel
  end

  def self.send_entry_stitch_request entry_id
    # It's possible an entry will have been deleted since the stitch request was queued.
    entry = Entry.where(id: entry_id).first
    sent = false
    if entry && entry.importer.try(:attachment_archive_setup).try(:combine_attachments)
      stitch_request = generate_stitch_request_for_entry(entry)

      if !stitch_request.blank?
        StitchQueueItem.create! stitch_type: Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE, stitch_queuable_type: Entry.name, stitch_queuable_id: entry.id
        OpenChain::SQS.send_json stitcher_info('request_queue'), stitch_request
        sent = true
      end
    end
    sent
  end

  def self.generate_stitch_request_for_entry entry
    attachment_order = "#{entry.importer.attachment_archive_setup.combined_attachment_order}".split("\n").collect {|n| n.strip.upcase}

    unordered_attachments = []
    ordered_attachments = []

    # We need to record the approximate moment in time when we assembled the stitch request so that can be used on the backend to determine
    # if there have been any updates to the attachments after this time.
    stitch_time = Time.now.iso8601

    entry.attachments.select {|a| a.attachment_type != Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE && a.stitchable_attachment?}.each do |a|
      if attachment_order.include? a.attachment_type.try(:upcase)
        ordered_attachments << a
      else
        unordered_attachments << a
      end
    end

    # Just sort unordered attachments by the updated_date in ascending order, we'll plop them onto the request after the ordered ones
    unordered_attachments = unordered_attachments.sort_by {|a| a.updated_at}
    sort_order = {}
    attachment_order.each_with_index {|o, x| sort_order[o] = x}

    # All we're doing here is using the attachment_order index from above as the ranking for the sort order (lowest to highest)
    # and the falling back to the update date if the doc types are the same
    ordered_attachments = ordered_attachments.sort do |a, b|
      s = sort_order[a.attachment_type.upcase] <=> sort_order[b.attachment_type.upcase]
      if s == 0
        s = a.updated_at <=> b.updated_at
      end
      s
    end

    if ordered_attachments.length > 0 || unordered_attachments.length > 0
      generate_stitch_request(entry, (ordered_attachments + unordered_attachments), {'time' => stitch_time})
    else
      {}
    end
  end

  def self.generate_stitch_request attachable, attachments, reference_hash
    request = {'stitch_request' => {}}

    source_files = attachments.collect {|a| {'path' => "/#{a.attached.options[:bucket]}/#{a.attached.path}", 'service' => 's3'}}
    request['stitch_request']['source_files'] = source_files
    # Anything sent under the reference_info key will be echo'ed back to us by the stitcher process.  We can use this
    # as the means for tagging requests/responses with any identifying information needed.  The only thing
    # the stitcher process expects is for the reference_info value to be a hash.  If there is a 'key' key in the hash
    # it will use it as the request identifier in log messages, but won't fail if the value isn't there.
    reference_key = "#{attachable.class.name}-#{attachable.id}"
    request['stitch_request']['reference_info'] = {'key' => reference_key}.merge reference_hash
    request['stitch_request']['destination_file'] = {'path' => "/chain-io/#{MasterSetup.get.uuid}/stitched/#{reference_key}.pdf", 'service' => 's3'}

    request
  end

  def self.process_entry_stitch_response message_hash
    # Technically our spec supports multiple errors, but in practice the stitcher only actually returns a single error message.
    # All errors are also logged in the stitcher logs as well, so we can correlate the two if we needed more information.
    if message_hash['stitch_response']['errors']
      # Just raise / log the errors as exceptions...that way we know about them.  We also have to make sure this method runs without 
      # error otherwise the queue message isn't deleted.
      begin
        raise "Failed to stitch together documents for reference key #{message_hash['stitch_response']['reference_key']}: #{message_hash['stitch_response']['errors'][0]['message']}"
      rescue => e
        # We have to raise / catch / log this, otherwise the stitch response message isn't removed from the queue...which is not what we want
        # Swallow this main excpetion error we get when the docs have some issue w/ the pdf and the pdf is not capable of being stitched together
        e.log_me unless e.message =~ /Unexpected Exception in open_reader\(\)\nUnhandled Java Exception:\njava\.lang\.NullPointerException\n/
      end
      return nil
    end

    message_hash = message_hash['stitch_response']

    split_key = message_hash['reference_info']['key'].split("-")
    entity = split_key[0].constantize.find split_key[1].to_i

    bucket, key = OpenChain::S3.parse_full_s3_path message_hash['destination_file']['path']
    OpenChain::S3.download_to_tempfile(bucket, key) do |f|
      Attachment.add_original_filename_method f
      f.original_filename = "#{entity.entry_number}.pdf"

      Attachment.transaction do 
        attachment = entity.attachments.build
        attachment.attachment_type = Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE
        attachment.attached = f
        # Use the created_at timestamp to record the actual time the stitch request was 
        # assembled.  This gives us a precise moment in time to use for finding
        # which other attachments on the entry have been modified since the request was assembled.
        attachment.created_at = Time.iso8601(message_hash['reference_info']['time'])
        attachment.save!

        item = StitchQueueItem.where(stitch_type: Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE, stitch_queuable_type: entity.class.name, stitch_queuable_id: entity.id).first
        item.destroy if item

        # Clear out any other archive packets already associated with this entry
        entity.attachments.where("NOT attachments.id = ?", attachment.id).where(:attachment_type => Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE).destroy_all
      end

      # Now that we've moved the file to its final attachment location, we can delete it from the stitched path
      OpenChain::S3.delete bucket, key
    end
    true
  end

  def self.consume_stitch_responses
    OpenChain::SQS.retrieve_messages_as_hash stitcher_info("response_queue") do |message_hash|
      process_entry_stitch_response message_hash
    end
  end

  def self.send_outstanding_stitch_requests
    Entry.
      uniq.
      joins(importer: :attachment_archive_setup).
      joins(:broker_invoices).
      joins("INNER JOIN attachments a on a.attachable_id = entries.id and a.attachable_type = '#{Entry.name}' and a.attachment_type <> '#{Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE}'").
      joins("LEFT OUTER JOIN attachments ap on ap.attachable_id = entries.id and ap.attachable_type = '#{Entry.name}' and ap.attachment_type = '#{Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE}'").
      joins("LEFT OUTER JOIN stitch_queue_items sqi ON sqi.stitch_type = '#{Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE}' AND sqi.stitch_queuable_type = '#{Entry.name}' AND sqi.stitch_queuable_id = entries.id").
      where(attachment_archive_setups: {combine_attachments: true}).
      # Only return attachments that either don't have archive packets or have outdated ones
      where("ap.id IS NULL OR a.updated_at >= ap.created_at").
      # We only need to send new stitch requests when actual stitchable attachments have been updated
      where(Attachment.stitchable_attachment_extensions.collect{|ext| "a.attached_file_name LIKE '%#{ext}'"}.join(" OR ")).
      # Only return attachments for entries that have not already been queued
      where("sqi.id IS NULL").
      # We need to also make sure we're only sending stitch requests for those documents we're going to be archiving
      # By waiting till after we have invoices it also adds a period of delay where the entry info / attachments are likely to 
      # be their most volatile
      where("broker_invoices.invoice_date >= attachment_archive_setups.start_date").
      where("a.is_private IS NULL or a.is_private = 0").
      order("entries.release_date ASC").
      pluck("entries.id").each do |id|

        send_entry_stitch_request id
    end
    nil
  end

  private 
    def self.get_env
      en = "dev"
      case Rails.env
        when "production"
          en = "prod"
        when "test"
          en = "test"
      end
      en
    end
    private_class_method :get_env

    def self.stitcher_info key
      @@stitcher_info ||= YAML.load_file(File.join(Rails.root, "config", "stitcher.yml"))[Rails.env]
      @@stitcher_info[key]
    end
    private_class_method :stitcher_info
end
