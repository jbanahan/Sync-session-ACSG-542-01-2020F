require 'open_chain/custom_handler/ferguson/ferguson_entry_verification_xml_generator'
require 'open_chain/ftp_file_support'
require 'open_chain/s3'

module OpenChain; module CustomHandler; module Ferguson; class FergusonEntryArchivePacketSender
  include OpenChain::FtpFileSupport

  SYNC_TRADING_PARTNER = "FERGUSON_ENTRY_ARCHIVE_PACKET_SENDER".freeze
  VERIFICATION_XML_GENERATOR = OpenChain::CustomHandler::Ferguson::FergusonEntryVerificationXmlGenerator
  XML_SEND_SYNC_TRADING_PARTNER = VERIFICATION_XML_GENERATOR::SYNC_TRADING_PARTNER

  def self.run_schedulable _opts = {}
    self.new.process_entries
  end

  def process_entries
    entries_with_verification_xmls.each do |ent|
      Entry.transaction do
        # Only entries with archive packet attachments are returned by the entry-finding method.
        # There can be only one "Archive Packet"-type attachment per entry.
        archive_packet = ent.attachments.find { |att| att.attachment_type == "Archive Packet" }
        ftp_archive_packet(archive_packet, ent)
      end
    rescue StandardError => e
      e.log_me "entry #{ent.broker_reference}"
    end
  end

  def ftp_credentials
    connect_vfitrack_net("to_ecs/ferguson_docs#{MasterSetup.get.production? ? "" : "_test"}")
  end

  private

    # This wrapper exists to prevent having to join on a second group of sync records.
    # It adds a delay to the process to allow the customer time to process XMLs on their side before
    # receiving entry packets.
    def entries_with_verification_xmls
      Entry.joins(:sync_records)
           .where(sync_records: {trading_partner: XML_SEND_SYNC_TRADING_PARTNER})
           .where("sync_records.sent_at < ?", current_time - 4.hours)
           .where(id: entries_with_archive_packets_to_send)
    end

    def entries_with_archive_packets_to_send
      Entry.includes(:attachments)
           .joins(:attachments)
           .joins(Entry.need_sync_join_clause(SYNC_TRADING_PARTNER))
           .where(Entry.where_clause_for_need_sync)
           .where(customer_number: VERIFICATION_XML_GENERATOR.ferguson_customer_numbers)
           .where(attachments: {attachment_type: "Archive Packet"})
    end

    def ftp_archive_packet archive_packet, entry
      sync_record = SyncRecord.find_or_build_sync_record entry, SYNC_TRADING_PARTNER
      S3.download_to_tempfile(archive_packet.bucket, archive_packet.path, original_filename: file_name(entry.entry_number)) do |arc|
        ftp_sync_file arc, sync_record
      end
      sync_record.update!(sent_at: 1.second.ago, confirmed_at: 0.seconds.ago)
    end

    def file_name entry_number
      "#{VERIFICATION_XML_GENERATOR.filename_system_prefix}_#{entry_number}_EntryPacket_#{current_time.strftime("%Y%m%d%H%M%S")}.pdf"
    end

    def current_time
      ActiveSupport::TimeZone["America/New_York"].now
    end

end; end; end; end
