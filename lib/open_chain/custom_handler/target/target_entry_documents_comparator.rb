require 'open_chain/entity_compare/entry_comparator'
require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/custom_handler/target/target_document_packet_zip_generator'
require 'open_chain/custom_handler/target/target_cusdec_xml_generator'

module OpenChain; module CustomHandler; module Target; class TargetEntryDocumentsComparator
  extend OpenChain::EntityCompare::EntryComparator
  include OpenChain::EntityCompare::ComparatorHelper

  def self.accept? snapshot
    return false unless super(snapshot)

    # We only want to accept entries that have already had cusdecs sent to Target
    # The whole point of this class is to send newly attached Commercial Invoices and Other Customs Documents to
    # Target's TDOX system after a Cusdec has been sent.  These documents will be sent on the initial
    # Cusdec send (which is why we don't accept if there hasn't been a cusdec already sent), but they're often
    # attached AFTER that initial send and we don't want to have operation have to force a cusdec resend just to send them.
    snapshot.recordable&.customer_number == "TARGEN" && find_snapshot(snapshot&.recordable).present?
  end

  def self.find_snapshot entry
    entry&.sync_records&.find {|sr| sr.trading_partner == TargetCusdecXmlGenerator::SYNC_TRADING_PARTNER && sr.sent_at.present? }.present?
  end

  def self.compare _type, _id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    g = self.new
    g.process_new_documents(g.get_json_hash(old_bucket, old_path, old_version), g.get_json_hash(new_bucket, new_path, new_version))
  end

  def process_new_documents old_snapshot, new_snapshot
    return if old_snapshot.blank?

    added_documents = added_child_entities(old_snapshot, new_snapshot, "Attachment")

    tdox_documents = extract_target_tdox_documents(added_documents)

    if tdox_documents.present?
      entry = find_entity_object(new_snapshot)
      return unless entry

      Lock.db_lock(entry) do
        # It's possible the actual document records here could be blank if say an attachment was removed in the time between
        # generating and processing the snapshot - not likely, but possible, in which case the lookup will return nil.
        # So remove those (via compact) and we can just skip it.
        documents = tdox_documents.map {|d| find_entity_object(d) }.compact
        target_document_packet_zip_generator.generate_and_send_doc_packs(entry, attachments: documents) if documents.present?
      end
    end
  end

  def extract_target_tdox_documents added_documents
    document_types = TargetDocumentPacketZipGenerator::OTHER_DOCUMENT_TYPES

    added_documents.find_all {|document| document_types.include? mf(document, "att_attachment_type").to_s.upcase }
  end

  def target_document_packet_zip_generator
    TargetDocumentPacketZipGenerator.new
  end

end; end; end; end