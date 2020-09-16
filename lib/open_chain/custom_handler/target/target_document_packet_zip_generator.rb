require 'open_chain/zip_builder'
require 'open_chain/ftp_file_support'
require 'open_chain/custom_handler/target/target_support'
require 'open_chain/custom_handler/target/target_document_packet_xml_generator'

module OpenChain; module CustomHandler; module Target; class TargetDocumentPacketZipGenerator
  include OpenChain::FtpFileSupport
  include OpenChain::CustomHandler::Target::TargetSupport

  ENTRY_DOCUMENT_TYPES ||= ["ENTRY SUMMARY - F7501"].freeze
  OTHER_DOCUMENT_TYPES ||= ["OTHER USC DOCUMENTS", "COMMERCIAL INVOICE"].freeze

  def generate_and_send_doc_packs entry, attachments: default_attachments(entry), bills_of_lading: default_bills_of_lading(entry)
    create_document_packets(entry, attachments: attachments, bills_of_lading: bills_of_lading) do |zip|
      ftp_file zip, doc_pack_ftp_credentials
    end
  end

  def doc_pack_ftp_credentials
    connect_vfitrack_net("to_ecs/target_documents#{MasterSetup.get.production? ? "" : "_test"}")
  end

  # Creates and yields zip packets (.ie a tempfile) that should be suitable to directly
  # ftp to the desired locaton.
  #
  # In general, this will produce 1 or 2 zip files for each Bill of Lading on the entry.  One zip will
  # be for the 7501 attachment and the other will be for any "supporting documents" (.ie types "Other USC Documents"
  # and "Commercial Invoice")
  def create_document_packets entry, attachments: default_attachments(entry), bills_of_lading: default_bills_of_lading(entry)
    attachment_data = extract_attachments(attachments)
    Array.wrap(bills_of_lading).each do |bill_of_lading|
      attachment_data.each_pair do |_doc_type, doc_pack|
        create_zip_packet(entry, bill_of_lading, doc_pack) do |zip|
          yield zip
        end
      end
    end
    nil
  end

  private

    def default_attachments entry
      entry.attachments
    end

    def default_bills_of_lading entry
      entry.split_master_bills_of_lading
    end

    # Creates a single zip packet for the given entry, bill, attachments
    def create_zip_packet entry, bill_of_lading, attachments
      time = Time.zone.now.in_time_zone("America/New_York")

      OpenChain::ZipBuilder.create_zip_builder("TDOX_#{maersk_broker_vendor_number}_#{formatted_time(time)}.zip") do |builder|
        add_attachment_to_packet(builder, attachments)
        add_manifest_to_packet(builder, time, entry, bill_of_lading, attachments)

        yield builder.to_tempfile
      end
    end

    def add_attachment_to_packet builder, attachments
      attachments.each do |attachment|
        attachment.download_to_tempfile do |t|
          builder.add_file attachment.attached_file_name, t
        end
      end

      nil
    end

    def add_manifest_to_packet builder, time, entry, bill_of_lading, attachments
      xml = xml_generator
      doc = xml.generate_xml entry, bill_of_lading, attachments
      io = StringIO.new
      xml.write_xml doc, io
      io.rewind
      builder.add_file "METADATA_#{maersk_broker_vendor_number}_#{formatted_time(time)}.xml", io
      nil
    end

    def xml_generator
      OpenChain::CustomHandler::Target::TargetDocumentPacketXmlGenerator.new
    end

    def formatted_time time
      time.strftime("%Y%m%d%H%M%S%L")
    end

    def extract_attachments attachments
      attachment_data = {summary: [], other: []}
      attachments.each do |attachment|
        document_type = attachment.attachment_type.to_s.upcase.strip

        if document_type == "ENTRY SUMMARY - F7501"
          attachment_data[:summary] << attachment
        elsif ["OTHER USC DOCUMENTS", "COMMERCIAL INVOICE"].include? document_type
          attachment_data[:other] << attachment
        end
      end

      attachment_data.delete(:summary) if attachment_data[:summary].blank?
      attachment_data.delete(:other) if attachment_data[:other].blank?

      attachment_data
    end

end; end; end; end