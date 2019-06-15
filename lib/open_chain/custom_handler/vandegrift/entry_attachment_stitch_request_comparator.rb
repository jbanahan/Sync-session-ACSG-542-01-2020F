require 'open_chain/sqs'

module OpenChain; module CustomHandler; module Vandegrift; class EntryAttachmentStitchRequestComparator
  extend OpenChain::EntityCompare::EntryComparator
  include OpenChain::EntityCompare::ComparatorHelper

  def self.accept? snapshot
    return false unless super
    return false unless MasterSetup.get.custom_feature?("Document Stitching")
    accept = false
  
    # If combine attachments is enabled, then we're going to combine them, regardless of the start/end date
    # The start end date is more for control of the documents available to the archiver desktop program 
    # or the monthly archiver / ftp export process.
    snapshot.recordable&.importer&.attachment_archive_setup&.combine_attachments? == true
  end

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    self.new.compare_snapshots old_bucket, old_path, old_version, new_bucket, new_path, new_version
  end

  def compare_snapshots old_bucket, old_path, old_version, new_bucket, new_path, new_version
    compare get_json_hash(old_bucket, old_path, old_version), get_json_hash(new_bucket, new_path, new_version)
  end

  def compare old_json, new_json
    entry = find_entity_object(new_json)
    return if entry.nil?

    archive_setup = entry.importer.attachment_archive_setup
    return if archive_setup.nil?

    attachment_type_set = []
    if archive_setup.include_only_listed_attachments?
      attachment_type_set = Set.new(archive_attachment_types(archive_setup))
    end

    old_attachments = find_attachments_by_type old_json, attachment_type_set
    new_attachments = find_attachments_by_type new_json, attachment_type_set

    # We should also re-generate attachments when an Archive Packet is deleted
    if any_entities_missing_from_lists?(old_attachments, new_attachments) || archive_packet_deleted?(old_json, new_json)
      Lock.db_lock(entry) do 
        # This method returns false if a stitch request was not sent (.ie no docs associated w/ the entry to send)
        if !generate_and_send_stitch_request(entry, archive_setup)
          # Destroy the archive packet if there's no attachments available to stitch and an archive packet exists
          archive_packet = entry.attachments.find {|a| a.attachment_type == Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE }
          if !archive_packet.nil?
            archive_packet.destroy
            entry.attachments.reload
            entry.create_snapshot User.integration, nil, "Archive Packet Builder"
          end
        end
      end
    end
  end

  def generate_stitch_request_for_entry entry, setup
    attachment_order = archive_attachment_types(setup)

    unordered_attachments = []
    ordered_attachments = []

    # We need to record the approximate moment in time when we assembled the stitch request so that can be used on the backend to determine
    # if there have been any updates to the attachments after this time.
    stitch_time = Time.zone.now.iso8601

    # The stichable attachment method skips any that are private attachments or not types of attachments we can stitch together (like zip files, etc)
    entry.attachments.select {|a| a.attachment_type != Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE && a.stitchable_attachment?}.each do |a|
      if attachment_order.include? a.attachment_type.try(:upcase)
        ordered_attachments << a
      else
        unordered_attachments << a
      end
    end

    include_only_listed_attachments = setup.include_only_listed_attachments?
    # Just sort unordered attachments by the updated_date in ascending order, we'll plop them onto the request after the ordered ones
    unordered_attachments =  include_only_listed_attachments ? [] : unordered_attachments.sort_by {|a| a.updated_at}
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

  def generate_and_send_stitch_request entry, archive_setup
    stitch_request = generate_stitch_request_for_entry(entry, archive_setup)
    if !stitch_request.blank?
      OpenChain::SQS.send_json sqs_queue, stitch_request
      return true
    else
      return false
    end
  end

  private 
    def sqs_queue
      queue = MasterSetup.secrets["pdf_stitcher"].try(:[], "request_queue")
      raise "No 'request_queue' key found under 'pdf_stitcher' config in secrets.yml." if queue.blank?
      queue
    end

    def find_attachments_by_type json, attachment_type_list, skip_archive_attachment: true
      attachments = json_child_entities(json, "Attachment")
      archive_type = Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE.to_s.upcase

      # Exclude any that are private attachments, which can never get stitched
      attachments.reject do |a|
        attachment_type = mf(a, "att_attachment_type").to_s.upcase
        mf(a, "att_private") || (skip_archive_attachment && attachment_type == archive_type) || (attachment_type_list.size > 0 && !attachment_type_list.include?(attachment_type))
      end
    end

    def archive_packet_deleted? old_json, new_json
      old_archive_attachment = find_attachments_by_type(old_json, [Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE.to_s.upcase], skip_archive_attachment: false)
      return false if old_archive_attachment.length == 0

      new_archive_attachment = find_attachments_by_type(new_json, [Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE.to_s.upcase], skip_archive_attachment: false)
      # if the new snapshot is missing an archive attachment, it was deleted
      return new_archive_attachment.length == 0
    end

    def send_stitch_request_for_entry entry
      stitch_request = generate_stitch_request_for_entry(entry)
    end

    def archive_attachment_types setup
      setup.combined_attachment_order.split("\n").collect {|n| n.strip.upcase}
    end

    def generate_stitch_request attachable, attachments, reference_hash
      request = {'stitch_request' => {}}

      source_files = attachments.collect {|a| {'path' => "/#{a.bucket}/#{a.path}", 'service' => 's3'}}
      request['stitch_request']['source_files'] = source_files
      # Anything sent under the reference_info key will be echo'ed back to us by the stitcher process.  We can use this
      # as the means for tagging requests/responses with any identifying information needed.  The only thing
      # the stitcher process expects is for the reference_info value to be a hash.  If there is a 'key' key in the hash
      # it will use it as the request identifier in log messages, but won't fail if the value isn't there.
      reference_key = "#{attachable.class.name}-#{attachable.id}"
      request['stitch_request']['reference_info'] = {'key' => reference_key}.merge reference_hash
      request['stitch_request']['destination_file'] = {'path' => "/chain-io/#{MasterSetup.get.uuid}/stitched/#{reference_key}-#{Time.zone.now.to_f}.pdf", 'service' => 's3'}

      request
    end

end; end; end; end