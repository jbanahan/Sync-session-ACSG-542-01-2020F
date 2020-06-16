require 'open_chain/zip_builder'
require 'open_chain/custom_handler/target/target_support'
require 'open_chain/custom_handler/target/target_document_packet_xml_generator'

module OpenChain; module CustomHandler; module Target; class TargetDocumentPacketZipGenerator
  include OpenChain::CustomHandler::Target::TargetSupport

  # Creates and yields zip packets (.ie a tempfile) that should be suitable to directly
  # ftp to the desired locaton.
  #
  # In general, this will produce 1 or 2 zip files for each Bill of Lading on the entry.  One zip will
  # be for the 7501 attachment and the other will be for any "supporting documents" (.ie types "Other USC Documents"
  # and "Commercial Invoice")
  def create_document_packets entry
    attachments = extract_attachments(entry)
    entry.split_master_bills_of_lading.each do |bill_of_lading|
      attachments.each_pair do |_doc_type, doc_pack|
        create_zip_packet(entry, bill_of_lading, doc_pack) do |zip|
          yield zip
        end
      end
    end
    nil
  end

  private

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

    def extract_attachments entry
      attachments = {summary: [], other: []}
      entry.attachments.each do |attachment|
        document_type = attachment.attachment_type.to_s.upcase.strip

        if document_type == "ENTRY SUMMARY - F7501"
          attachments[:summary] << attachment
        elsif ["OTHER USC DOCUMENTS", "COMMERCIAL INVOICE"].include? document_type
          attachments[:other] << attachment
        end
      end

      attachments.delete(:summary) if attachments[:summary].blank?
      attachments.delete(:other) if attachments[:other].blank?

      attachments
    end

end; end; end; end