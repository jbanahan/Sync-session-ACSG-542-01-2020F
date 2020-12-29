require 'open_chain/custom_handler/ferguson/ferguson_entry_verification_xml_generator'
require 'open_chain/ftp_file_support'
require 'open_chain/s3'

module OpenChain; module CustomHandler; module Ferguson; class FergusonEntryBillingPacketSender
  include OpenChain::FtpFileSupport

  SYNC_TRADING_PARTNER = "FERGUSON_ENTRY_BILLING_PACKET_SENDER".freeze
  VERIFICATION_XML_GENERATOR = OpenChain::CustomHandler::Ferguson::FergusonEntryVerificationXmlGenerator
  XML_SEND_SYNC_TRADING_PARTNER = VERIFICATION_XML_GENERATOR::SYNC_TRADING_PARTNER
  SEND_COUNT = "send_count".freeze

  def self.run_schedulable _opts = {}
    self.new.process_entries
  end

  def process_entries
    entries_to_send.each do |ent|
      Lock.db_lock(ent) do
        # Only entries with archive packet attachments are returned by the entry-finding method.
        # There can be only one "Archive Packet"-type attachment per entry.
        archive_packet = ent.attachments.find { |att| att.attachment_type == "Archive Packet" }
        ftp_archive_packet(archive_packet, ent)
      end
    rescue StandardError => e
      e.log_me "entry #{ent.broker_reference}"
    end
    nil
  end

  def ftp_credentials
    connect_vfitrack_net("to_ecs/ferguson_billing_packet#{MasterSetup.get.production? ? "" : "_test"}")
  end

  private

    # In order to send one of these billing packets, all of the following conditions must be met.
    # 1. Declaration XML must have been sent 4+ hours ago to ensure that the entry exists in Thomson
    #    Reuters' system.
    # 2. The entry must have an Archive Packet attachment.  That's what we're sending.
    # 3. Billing Invoice or Broker Invoice attachment must have been added to entry between the last
    #    Billing Packet send (which could be never) and 4+ hours ago.  The delay is included here because
    #    we want to give the system time to stitch the PDF(s) into the Archive Packet.  There's no current
    #    way (as of 12/2020) to know what files are actually contained in the Archive Packet, but delay
    #    should ensure billing content is included by the time it is sent.
    def entries_to_send
      delay_time = current_time - 4.hours
      sync_declaration_join =
        <<~SQL
          INNER JOIN sync_records AS sync_declaration ON
            sync_declaration.syncable_id = entries.id AND
            sync_declaration.syncable_type = 'Entry' AND
            sync_declaration.trading_partner = 'FERGUSON_DECLARATION'
        SQL
      attach_archive_packet_join =
        <<~SQL
          INNER JOIN attachments AS attach_archive_packet ON
            attach_archive_packet.attachable_id = entries.id AND
            attach_archive_packet.attachable_type = 'Entry' AND
            attach_archive_packet.attachment_type = 'Archive Packet'
        SQL
      attach_invoice_join =
        <<~SQL
          INNER JOIN attachments AS attach_invoice ON
            attach_invoice.attachable_id = entries.id AND
            attach_invoice.attachable_type = 'Entry' AND
            attach_invoice.attachment_type IN ('Broker Invoice', 'Billing Invoice')
        SQL

      Entry.includes(:sync_records, :attachments)
           .joins(sync_declaration_join)
           .joins(attach_archive_packet_join)
           .joins(attach_invoice_join)
           .joins(Entry.need_sync_join_clause(SYNC_TRADING_PARTNER))
           .where(Entry.where_clause_for_need_sync(join_table: "attach_invoice", updated_at_column: "created_at"))
           .where(customer_number: VERIFICATION_XML_GENERATOR.ferguson_customer_numbers)
           .where("sync_declaration.sent_at < ?", delay_time)
           .where("attach_invoice.created_at < ?", delay_time)
           .distinct
    end

    def ftp_archive_packet archive_packet, entry
      sync_record = SyncRecord.find_or_build_sync_record entry, SYNC_TRADING_PARTNER
      next_sequence_number = calculate_next_sequence_number sync_record
      output_name = file_name(entry.entry_number, next_sequence_number)
      S3.download_to_tempfile(archive_packet.bucket, archive_packet.path, original_filename: output_name) do |arc|
        ftp_sync_file arc, sync_record
      end

      sync_record.set_context SEND_COUNT, next_sequence_number
      sync_record.sent_at = 1.second.ago
      sync_record.confirmed_at = 0.seconds.ago
      sync_record.save!
    end

    def calculate_next_sequence_number sync_record
      prev_send_count = sync_record ? sync_record.context[SEND_COUNT] : nil
      (prev_send_count.to_i + 1).to_s.rjust(2, "0")
    end

    def file_name entry_number, sequence_number
      "VFI_#{VERIFICATION_XML_GENERATOR.filename_system_prefix}_#{entry_number}_#{current_time.strftime("%Y%m%d%H%M%S")}_CBP_#{sequence_number}.pdf"
    end

    def current_time
      ActiveSupport::TimeZone["America/New_York"].now
    end

end; end; end; end