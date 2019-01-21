require 'open_chain/sqs'
require 'open_chain/s3'

module OpenChain; module CustomHandler; module Vandegrift; class StitcherResponseConsumer

  def self.run_schedulable
    if MasterSetup.get.custom_feature?("Document Stitching")
      self.delay.consume_stitch_responses
    end
  end

  def self.consume_stitch_responses
    OpenChain::SQS.poll stitcher_info("response_queue") do |message_hash|
      process_stitch_response message_hash
    end
  end

  def self.process_stitch_response message_hash
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

      Lock.db_lock(entity) do 
        # There's a possibility (though small) that another archive packet could have been created and added since the one we're receiving was
        # If so, we can just skip this one.
        created_at = Time.zone.parse(message_hash['reference_info']['time'])
        other_archive = entity.attachments.find { |a| a.attachment_type == Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE }
        if other_archive.nil? || other_archive.created_at <= created_at 
          attachment = entity.attachments.build
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

      # Now that we've moved the file to its final attachment location, we can delete it from the stitched path
      OpenChain::S3.delete bucket, key
    end
    true
  end


  private
    def self.stitcher_info key
      Rails.application.config.attachment_stitcher[key.to_s]
    end
    private_class_method :stitcher_info

end; end; end; end