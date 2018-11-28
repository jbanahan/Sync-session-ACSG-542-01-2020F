require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/entity_compare/entry_comparator'
require 'open_chain/ftp_file_support'
require 'open_chain/s3'

module OpenChain; module CustomHandler; module Vandegrift; class VandegriftEntryArchiveComparator
  extend OpenChain::EntityCompare::EntryComparator
  include OpenChain::EntityCompare::ComparatorHelper
  include OpenChain::FtpFileSupport

  def self.accept? snapshot
    accept = false
    if super 
      e = snapshot.recordable
      archive_setup = AttachmentArchiveSetup.where(company_id: e.importer_id).first
      if archive_setup.try(:send_in_real_time?)
        accept = e.broker_invoices.any?{ |bi| bi.invoice_date >= archive_setup.start_date && (archive_setup.end_date.nil? || bi.invoice_date <= archive_setup.end_date) }
      end
    end
    accept
  end

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    self.new.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
  end

  def compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    new_json = get_json_hash(new_bucket, new_path, new_version)
    return unless new_att_id = get_archive_packet_id(new_json)
    
    old_json = get_json_hash old_bucket, old_path, old_version
    old_att_id = get_archive_packet_id old_json
    
    archive = Attachment.where(id: new_att_id).first
    ftp_archive(archive) if archive && new_att_id != old_att_id
  end

  def get_archive_packet_id json
    json_child_entities(json, "Attachment").find{ |a| a["model_fields"]["att_attachment_type"] == "Archive Packet" }.try(:[], "record_id")
  end

  def ftp_archive archive
    ent = archive.attachable
    filename = "#{ent.entry_number}_#{archive.attachment_type.gsub(" ", "_")}_#{Time.zone.now.strftime("%Y%m%d%H%M")}.pdf"
    S3.download_to_tempfile archive.bucket, archive.path, original_filename: filename  do |arc|
      ftp_file arc, connect_vfitrack_net("to_ecs/attachment_archive/#{ent.customer_number}")
    end
  end

end; end; end; end
