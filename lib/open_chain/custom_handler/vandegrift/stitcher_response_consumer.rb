require 'open_chain/sqs'
require 'open_chain/s3'

module OpenChain; module CustomHandler; module Vandegrift; class StitcherResponseConsumer

  def self.run_schedulable
    if MasterSetup.get.custom_feature?("Document Stitching")
      self.delay.consume_stitch_responses
    end
  end

  def self.consume_stitch_responses
    OpenChain::SQS.poll(response_queue, include_attributes: true) do |message_hash, message_attributes|
      begin # rubocop:disable Style/RedundantBegin
        process_stitch_response message_hash
      rescue OpenChain::S3::NoSuchKeyError
        # If we've tried several times to process a stitch response and it raises a no key error, then just skip the message
        # If the file isn't found...just throw a ':skip_delete' symbol (which SQS handles as essentially a no-op)..the
        # message will be reprocessed later.
        throw :skip_delete unless message_attributes.approximate_receive_count > 10
      end
    end
  end

  def self.process_stitch_response message_hash
    # Technically our spec supports multiple errors, but in practice the stitcher only actually returns a single error message.
    # All errors are also logged in the stitcher logs as well, so we can correlate the two if we needed more information.
    if message_hash['stitch_response']['errors']
      # Just raise / log the errors as exceptions...that way we know about them.  We also have to make sure this method runs without
      # error otherwise the queue message isn't deleted.
      begin
        raise "Failed to stitch together documents for reference key #{message_hash['stitch_response']['reference_key']}: #{message_hash['stitch_response']['errors'][0]['message']}" # rubocop:disable Layout/LineLength
      rescue StandardError => e
        # We have to raise / catch / log this, otherwise the stitch response message isn't removed from the queue...which is not what we want
        # Swallow this main excpetion error we get when the docs have some issue w/ the pdf and the pdf is not capable of being stitched together
        e.log_me unless swallow_error?(e.message)
      end
      return nil
    end

    message_hash = message_hash['stitch_response']

    split_key = message_hash['reference_info']['key'].split("-")
    entity = split_key[0].constantize.where(id: split_key[1].to_i).first
    bucket, key = OpenChain::S3.parse_full_s3_path message_hash['destination_file']['path']
    if entity
      OpenChain::S3.download_to_tempfile(bucket, key) do |f|
        Attachment.add_original_filename_method f
        f.original_filename = "#{entity.entry_number}.pdf"

        Lock.db_lock(entity) do
          # There's a possibility (though small) that another archive packet could have been created and added since the one we're receiving was
          # If so, we can just skip this one.
          created_at = Time.zone.parse(message_hash['reference_info']['time'])
          other_archive = entity.attachments.find { |a| a.attachment_type == Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE }
          if other_archive.nil? || other_archive.created_at <= created_at
            attachment = entity.attachments.build
            # Since we're composing a (potentially large) file from files that have already been virus scanned, we can skip the attachment
            # virus scanning for the archive packets.
            attachment.skip_virus_scan = true
            attachment.attachment_type = Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE
            attachment.attached = f
            # Use the created_at timestamp to record the actual time the stitch request was
            # assembled.  This gives us a precise moment in time to use for finding
            # which other attachments on the entry have been modified since the request was assembled.
            attachment.created_at = created_at
            attachment.save!

            # Clear out any other archive packets already associated with this entry
            entity.attachments.where("NOT attachments.id = ?", attachment.id).where(attachment_type: Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE).destroy_all
            entity.create_snapshot User.integration, nil, "Archive Packet"
          end
        end
      end
    end
    # Now that we've moved the file to its final attachment location, we can delete it from the stitched path
    OpenChain::S3.delete bucket, key

    true
  end

  private

    def self.response_queue
      queue = MasterSetup.secrets["pdf_stitcher"].try(:[], "response_queue")
      raise "No 'response_queue' key found under 'pdf_stitcher' config in secrets.yml." if queue.blank?
      queue
    end
    private_class_method :response_queue

    def self.swallow_error? message
      file_missing_error?(message) || java_error?(message)
    end
    private_class_method :swallow_error?

    def self.java_error? message
      (message =~ /Unhandled Java Exception in create_output\(\):/) && [/java.io.EOFException/, /java.lang.ClassCastException/].any? {|e| message.match? e }
    end
    private_class_method :java_error?

    def self.file_missing_error? message
      # This is the error message that the S3 api raises if the path given can't be found.  This will happen sometimes when
      # the files referenced change after the stitch message was queued.  We don't really need to track this, it's not really
      # an error condition.  It happens naturally from time to time.
      message =~ /The specified key does not exist/i
    end
    private_class_method :file_missing_error?

end; end; end; end