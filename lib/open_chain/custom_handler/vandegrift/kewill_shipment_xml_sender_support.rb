require 'open_chain/ftp_file_support'
require 'open_chain/custom_handler/vandegrift/kewill_shipment_xml_support'

# This module is for using when you need to actually send (FTP) Shipment / Invoice
# information to Customs Managment (aka Kewill).
#
# You're process is reponsible for building the shipment structs from whatever source data
# you're building for.  Once completed you would use the generate_and_send_shipment_xml/
# generate_and_send_invoice_xml to send the data to Customs Management.

module OpenChain; module CustomHandler; module Vandegrift; module KewillShipmentXmlSenderSupport
  extend ActiveSupport::Concern
  include OpenChain::FtpFileSupport
  include OpenChain::CustomHandler::Vandegrift::KewillShipmentXmlSupport

  # Generates XML data to Customs Management (CM / CMUS) that represents a full
  # shipment.
  # shipments - an array (or single object) of the CiLoadEntry structs
  # sync_records - (Optional) - if present you can pass a single sync record
  # to use for the whole send process, or an array of SyncRecords, which should
  # be indexed 1 to 1 with the array of shipments passed in.  .ie 1st sync record
  # is for 1st shipment, 2nd sr for 2nd shipment, etc.
  def generate_and_send_shipment_xml shipments, sync_records: nil
    Array.wrap(shipments).each.each_with_index do |shipment, index|
      filename = _shipment_file_prefix(shipment)
      xml = generate_entry_xml shipment
      _send_xml(xml, filename, sync_record(sync_records, index))
    end
    nil
  end

  # Generates XML data to Customs Management (CM / CMUS) that represents a
  # Commercial Invoice.
  #
  # invoices - an array (or single object) of the CiLoadEntry structs
  # sync_records - (Optional) - if present you can pass a single sync record
  # to use for the whole send process, or an array of SyncRecords, which should
  # be indexed 1 to 1 with the array of shipments passed in.  .ie 1st sync record
  # is for 1st shipment, 2nd sr for 2nd shipment, etc.
  def generate_and_send_invoice_xml invoices, sync_records: nil
    Array.wrap(invoices).each_with_index do |invoice, index|
      filename = _invoice_file_prefix(invoice)
      xml = generate_entry_xml invoice, add_entry_info: false
      _send_xml(xml, filename, sync_record(sync_records, index))
    end
    nil
  end

  private

    def _send_xml xml, filename_prefix, sync_record
      filename = Attachment.get_sanitized_filename("#{filename_prefix}_#{Time.zone.now.strftime("%Y-%m-%dT%H-%M-%S")}")

      Tempfile.open([filename, ".xml"]) do |file|
        Attachment.add_original_filename_method(file, "#{filename}.xml")

        xml.write file
        file.flush

        # since sync records are optional, sync_record could be nil, but ftp_sync_file handles that already
        ftp_sync_file file, sync_record, ecs_connect_vfitrack_net("kewill_edi/to_kewill")
      end
    end

    def _shipment_file_prefix shipment
      id = shipment.file_number
      if id.blank? && shipment.edi_identifier
        id = shipment.edi_identifier.master_bill
        id = shipment.edi_identifier.house_bill if id.blank?
      end

      if id.blank? && shipment.bills_of_lading.present?
        bol = shipment.bills_of_lading.first

        id = bol.master_bill
        id = bol.house_bill if id.blank?
      end

      "CM_SHP_#{shipment.customer}_#{id}"
    end

    def _invoice_file_prefix invoice
      id = invoice.file_number
      if id.blank? && invoice.invoices.present?
        inv = invoice.invoices.first
        id = inv.file_number
        id = inv.invoice_number if id.blank?
      end

      "CM_CI_#{invoice.customer}_#{id}"
    end

    # We're expecting one of 3 things here...
    # nil - which means we're not using sync_records
    # a single sync record object - which means we're using a single sync record for all sends
    # an array of sync records - which means that we want the index position from the array given
    def sync_record sync_records, index
      return if sync_records.nil?
      if sync_records.respond_to?(:[])
        return sync_records[index]
      else
        return sync_records
      end
    end

end; end; end; end