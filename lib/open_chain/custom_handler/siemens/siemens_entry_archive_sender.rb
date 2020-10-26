require 'open_chain/custom_handler/siemens/siemens_ca_xml_billing_generator'
require 'open_chain/ftp_file_support'
require 'open_chain/s3'

module OpenChain; module CustomHandler; module Siemens; class SiemensEntryArchiveSender
  include OpenChain::FtpFileSupport

  attr_reader :start_date

  BROKER_CODE = 119
  SYNC_TRADING_PARTNER = "siemens_archive_sender".freeze
  BILLING_GENERATOR = OpenChain::CustomHandler::Siemens::SiemensCaXmlBillingGenerator
  XML_SYNC_TRADING_PARTNER = BILLING_GENERATOR::SYNC_TRADING_PARTNER
  TAX_IDS = BILLING_GENERATOR::TAX_IDS
  SYSTEM_DATE_ID = BILLING_GENERATOR::SYSTEM_DATE_ID

  def self.run_schedulable _opts = {}
    self.new.process_entries
  end

  def initialize
    @start_date = SystemDate.find_start_date(SYSTEM_DATE_ID)
    raise "SystemDate must be set." unless start_date
  end

  def process_entries
    logged_entries.each do |ent|
      Entry.transaction do
        archive = ent.attachments.find { |att| att.attachment_type == "Archive Packet" }
        ftp_archive(archive, ent.entry_number)
        sr = ent.find_or_initialize_sync_record("siemens_archive_sender")
        sr.update! sent_at: timestamp, confirmed_at: timestamp + 1.minute
      end
    rescue StandardError => e
      e.log_me "entry #{ent.broker_reference}"
    end
  end

  # This wrapper exists to prevent having to join on a second group of sync records
  # Siemens says they need time to process the XML "log" that proceeds each of these transmissions, hence the 12-hour delay.
  def logged_entries
    Entry.joins(:sync_records)
         .where(sync_records: {trading_partner: XML_SYNC_TRADING_PARTNER})
         .where("sync_records.sent_at < DATE_SUB(NOW(), INTERVAL 12 HOUR)")
         .where(id: entries)
  end

  def partner_id
    MasterSetup.get.production? ? "100502" : "1005029"
  end

  private

  def entries
    Entry.includes(:attachments)
         .joins(:attachments)
         .joins(importer: :system_identifiers)
         .joins(Entry.need_sync_join_clause(SYNC_TRADING_PARTNER))
         .where(Entry.where_clause_for_need_sync)
         .where(system_identifiers: {system: "Fenix", code: TAX_IDS})
         .where(attachments: {attachment_type: "Archive Packet"})
         .where("file_logged_date > ?", start_date)
  end

  def ftp_archive archive, entry_number
    fname = file_name(entry_number)
    S3.download_to_tempfile(archive.bucket, archive.path, original_filename: fname) do |arc|
      ftp_file arc, connect_vfitrack_net("to_ecs/siemens_hc/docs#{MasterSetup.get.production? ? "" : "_test"}")
    end
  end

  def file_name entry_number
    "#{partner_id}_CA_B3_#{BROKER_CODE}_#{entry_number}_#{timestamp(format: true)}.pdf"
  end

  def timestamp format: false
    @now ||= Time.zone.now
    format ? @now.strftime("%Y%m%d%H%M%S") : @now
  end

end; end; end; end
