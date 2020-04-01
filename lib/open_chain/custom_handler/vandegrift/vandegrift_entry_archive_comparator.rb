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
      archive_setup = attachment_archive_setup_for(e)
      if archive_setup&.send_in_real_time?
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
    cust_no = customer_number(ent)

    aas = self.class.attachment_archive_setup_for ent
    if aas.company.attachment_archive_setup.output_path.blank?
      filename = "#{ent.entry_number}_#{archive.attachment_type.gsub(" ", "_")}_#{Time.zone.now.strftime("%Y%m%d%H%M")}.pdf"
    else
      liquid_string = aas.company.attachment_archive_setup.output_path
      variables = {'attachment' => ActiveRecordLiquidDelegator.new(archive),
        'archive_attachment' => ActiveRecordLiquidDelegator.new(aas),
        'entry' => ActiveRecordLiquidDelegator.new(ent)}

      filename = Attachment.get_sanitized_filename(OpenChain::TemplateUtil.interpolate_liquid_string(liquid_string, variables))
    end

    S3.download_to_tempfile archive.bucket, archive.path, original_filename: filename  do |arc|
      ftp_file arc, connect_vfitrack_net("to_ecs/attachment_archive/#{cust_no}")
    end
  end

  def customer_number entry
    self.class.attachment_archive_setup_for(entry)&.send_as_customer_number.presence || entry.customer_number
  end

  def self.attachment_archive_setup_for entry
    return nil unless entry&.importer

    AttachmentArchiveSetup.setups_for(entry.importer).first
  end

end; end; end; end
