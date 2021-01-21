require 'action_view/helpers/number_helper'
require 'open_chain/ftp_file_support'
require 'open_chain/xml_builder'

# Generates a billing invoice XML file (e.g. basis for EDI 310, but doesn't have to be) for a broker invoice.
# It's assumed that each broker invoice will kick out its own individual XML even though the document
# structure can technically handle multiple.
module OpenChain; module CustomHandler; module Generic; class BillingInvoiceGenerator
  include ActionView::Helpers::NumberHelper
  include OpenChain::FtpFileSupport
  include OpenChain::XmlBuilder

  SYNC_TRADING_PARTNER = 'BILLING_INVOICE'.freeze

  def generate_and_send broker_invoice
    doc = generate_xml broker_invoice
    send_xml doc, broker_invoice
    nil
  end

  def generate_xml broker_invoice
    doc, elem_root = build_xml_document "BillingInvoices"
    make_document_info_element elem_root, broker_invoice
    make_billing_invoice_element elem_root, broker_invoice
    doc
  end

  private

    def make_document_info_element elem_root, broker_inv
      elem_doc_info = add_element elem_root, "DocumentInfo"
      add_element elem_doc_info, "DocumentSender", "VFITRACK"
      add_element elem_doc_info, "DocumentRecipient", broker_inv.customer_number
      add_element elem_doc_info, "CreatedAt", format_datetime(ActiveSupport::TimeZone["America/New_York"].now)
      elem_doc_info
    end

    def format_datetime dt
      dt&.strftime('%Y-%m-%dT%H:%M:%S%z')
    end

    def make_billing_invoice_element elem_root, broker_inv
      elem_billing_invoice = add_element elem_root, "BillingInvoice"
      add_element elem_billing_invoice, "InvoiceNumber", broker_inv.invoice_number
      add_element elem_billing_invoice, "InvoiceDate", format_date(broker_inv.invoice_date)
      add_element elem_billing_invoice, "InvoiceTotal", format_decimal(broker_inv.invoice_total)
      add_element elem_billing_invoice, "Currency", broker_inv.currency
      add_element elem_billing_invoice, "CustomerNumber", broker_inv.customer_number
      add_element elem_billing_invoice, "FiscalYear", broker_inv.fiscal_year
      add_element elem_billing_invoice, "FiscalMonth", broker_inv.fiscal_month

      vandegrift = Company.with_identifier("Filer Code", "316").first
      if vandegrift
        address_remit_to = Address.where(company: vandegrift, address_type: "Remit To").first
        if address_remit_to
          make_remit_to_element elem_billing_invoice, address_remit_to
        end
      end

      if broker_inv.entry.ult_consignee_name.present?
        make_consignee_element elem_billing_invoice, broker_inv.entry
      end

      if broker_inv.bill_to_name.present?
        make_bill_to_element elem_billing_invoice, broker_inv
      end

      broker_inv.broker_invoice_lines.each do |bil|
        make_billing_invoice_line_element elem_billing_invoice, bil, broker_inv.entry
      end

      make_entry_element elem_billing_invoice, broker_inv.entry

      elem_billing_invoice
    end

    def format_date d
      d&.strftime('%Y-%m-%d')
    end

    # Looking for the original number from the database field with any pointless zeros removed.
    def format_decimal val
      number_with_precision(val, precision: 10, strip_insignificant_zeros: true)
    end

    def make_remit_to_element elem_billing_invoice, address
      elem_remit_to = add_element elem_billing_invoice, "RemitTo"
      add_element elem_remit_to, "Name", address.name
      add_element elem_remit_to, "Address1", address.line_1
      add_element elem_remit_to, "Address2", address.line_2
      add_element elem_remit_to, "City", address.city
      add_element elem_remit_to, "State", address.state
      add_element elem_remit_to, "PostalCode", address.postal_code
      add_element elem_remit_to, "Country", address.country&.iso_code
      elem_remit_to
    end

    def make_consignee_element elem_billing_invoice, entry
      elem_consignee = add_element elem_billing_invoice, "Consignee"
      add_element elem_consignee, "Name", entry.ult_consignee_name
      add_element elem_consignee, "Address1", entry.consignee_address_1
      add_element elem_consignee, "Address2", entry.consignee_address_2
      add_element elem_consignee, "City", entry.consignee_city
      add_element elem_consignee, "State", entry.consignee_state
      add_element elem_consignee, "PostalCode", entry.consignee_postal_code
      add_element elem_consignee, "Country", entry.consignee_country_code
      elem_consignee
    end

    def make_bill_to_element elem_billing_invoice, broker_inv
      elem_bill_to = add_element elem_billing_invoice, "BillTo"
      add_element elem_bill_to, "Name", broker_inv.bill_to_name
      add_element elem_bill_to, "Address1", broker_inv.bill_to_address_1
      add_element elem_bill_to, "Address2", broker_inv.bill_to_address_2
      add_element elem_bill_to, "City", broker_inv.bill_to_city
      add_element elem_bill_to, "State", broker_inv.bill_to_state
      add_element elem_bill_to, "PostalCode", broker_inv.bill_to_zip
      add_element elem_bill_to, "Country", broker_inv.bill_to_country&.iso_code
      elem_bill_to
    end

    def make_billing_invoice_line_element elem_billing_invoice, broker_inv_line, entry
      elem_billing_invoice_line = add_element elem_billing_invoice, "BillingInvoiceLine"
      add_element elem_billing_invoice_line, "ChargeCode", broker_inv_line.charge_code
      # Some customers want charges they don't owe us displayed on their bills (Duty Paid Direct, Freight Direct).
      # For those cases, the BilledAmount should be zero and the DisplayAmount should be the amount.
      billed_amount = !broker_inv_line.duty_paid_direct_charge_code? && !broker_inv_line.freight_direct_charge_code?
      add_element elem_billing_invoice_line, "BilledAmount", format_decimal(billed_amount ? broker_inv_line.charge_amount : 0)
      add_element elem_billing_invoice_line, "DisplayAmount", format_decimal(billed_amount ? 0 : broker_inv_line.charge_amount)
      add_element elem_billing_invoice_line, "ChargeDescription", broker_inv_line.charge_description
      # For Emser, at least, the first customer getting one of these files, entry-level vendor names appears
      # to be 'better' than the broker invoice line value, which is typically blank or 'US CUSTOMS & BORDER PROTECTION'.
      # Of course, this is a line-level field here and the entry-level Vendor Names field can and does contain
      # multiple vendor names, which may not be ideal either.  <shrug>
      add_element elem_billing_invoice_line, "VendorName", eat_newlines(entry.vendor_names).presence || broker_inv_line.vendor_name
      add_element elem_billing_invoice_line, "VendorReference", broker_inv_line.vendor_reference
      elem_billing_invoice_line
    end

    def eat_newlines str
      str&.gsub("\n ", ",")
    end

    def make_entry_element elem_billing_invoice, entry
      elem_entry = add_element elem_billing_invoice, "Entry"
      add_element elem_entry, "CustomerNumber", entry.customer_number
      add_element elem_entry, "EntryNumber", entry.entry_number
      add_element elem_entry, "BrokerReference", entry.broker_reference
      add_element elem_entry, "CustomsEntryType", entry.entry_type
      add_element elem_entry, "ModeOfTransportation", convert_ship_mode(entry)
      add_element elem_entry, "CustomsModeOfTransportation", entry.transport_mode_code
      add_element elem_entry, "ExportDate", format_date(entry.export_date)
      add_element elem_entry, "ArrivalDate", format_date(entry.arrival_date)
      add_element elem_entry, "ImportDate", format_date(entry.import_date)
      add_element elem_entry, "EntryFiledDateTime", format_datetime(entry.entry_filed_date)
      add_element elem_entry, "ReleaseDateTime", format_datetime(entry.release_date)
      add_element elem_entry, "Vessel", entry.vessel
      add_element elem_entry, "VoyageFlightNumber", entry.voyage
      add_element elem_entry, "CarrierCode", entry.carrier_code
      make_countries_element "CountriesOfOrigin", elem_entry, entry.origin_country_codes
      make_countries_element "CountriesOfExport", elem_entry, entry.export_country_codes
      add_element elem_entry, "MerchandiseDescription", entry.merchandise_description
      make_containers_element elem_entry, entry
      make_reference_numbers_element elem_entry, entry
      make_locations_element elem_entry, entry
      elem_entry
    end

    def convert_ship_mode entry
      if entry.ocean_mode?
        "Sea"
      elsif entry.air_mode?
        "Air"
      elsif entry.truck_mode?
        "Truck"
      elsif entry.rail_mode?
        "Rail"
      else
        "Other"
      end
    end

    def make_countries_element parent_element_name, elem_entry, country_codes
      country_code_array = Entry.split_newline_values(country_codes)
      elem_countries = nil
      if country_code_array.length > 0
        elem_countries = add_element elem_entry, parent_element_name
        country_code_array.each do |country_iso|
          add_element elem_countries, "Country", country_iso
        end
      end
      elem_countries
    end

    def make_containers_element elem_entry, entry
      elem_containers = nil
      if entry.containers.length > 0
        elem_containers = add_element elem_entry, "Containers"
        entry.containers.each do |cont|
          make_container_element elem_containers, cont
        end
      end
      elem_containers
    end

    def make_container_element elem_containers, cont
      elem_container = add_element elem_containers, "Container"
      add_element elem_container, "ContainerNumber", cont.container_number
      add_element elem_container, "ContainerSize", cont.container_size
      add_element elem_container, "LoadType", cont.fcl_lcl
      add_element elem_container, "Weight", cont.weight.to_s
      add_element elem_container, "WeightUom", "KG"
      add_element elem_container, "Quantity", cont.quantity.to_s
      add_element elem_container, "QuantityUom", cont.uom
      add_element elem_container, "Teus", cont.teus.to_s
      elem_container
    end

    def make_reference_numbers_element elem_entry, entry
      elem_ref_numbers = add_element elem_entry, "ReferenceNumbers"
      Entry.split_newline_values(entry.master_bills_of_lading).each do |mbol|
        make_reference_number_element "MasterBillOfLading", elem_ref_numbers, mbol
      end
      Entry.split_newline_values(entry.house_bills_of_lading).each do |hbol|
        make_reference_number_element "HouseBillOfLading", elem_ref_numbers, hbol
      end
      Entry.split_newline_values(entry.it_numbers).each do |it_num|
        make_reference_number_element "ItNumber", elem_ref_numbers, it_num
      end
      Entry.split_newline_values(entry.customer_references).each do |ref_num|
        make_reference_number_element "CustomerReference", elem_ref_numbers, ref_num
      end
      Entry.split_newline_values(entry.po_numbers).each do |ord_num|
        make_reference_number_element "OrderNumber", elem_ref_numbers, ord_num
      end
      elem_ref_numbers
    end

    def make_reference_number_element code, elem_ref_numbers, value
      elem_ref_num = add_element elem_ref_numbers, "ReferenceNumber"
      add_element elem_ref_num, "Code", code
      add_element elem_ref_num, "Value", value
      elem_ref_num
    end

    def make_locations_element elem_entry, entry
      elem_locations = add_element elem_entry, "Locations"
      if entry.lading_port
        make_location_element "PortOfLading", elem_locations, entry.lading_port_code, "ScheduleK", entry.lading_port
      end
      if entry.origin_airport
        make_location_element "OriginAirportCode", elem_locations, entry.origin_airport_code, "IATA", entry.origin_airport
      end
      if entry.entry_port
        make_location_element "PortOfEntry", elem_locations, entry.entry_port_code, "ScheduleD", entry.entry_port
      end
      if entry.unlading_port
        make_location_element "PortOfUnlading", elem_locations, entry.unlading_port_code, "ScheduleD", entry.unlading_port
      end
      elem_locations
    end

    def make_location_element location_type, elem_locations, location_code, location_code_type, port
      elem_loc = add_element elem_locations, "Location"
      add_element elem_loc, "LocationType", location_type
      add_element elem_loc, "LocationCode", location_code
      add_element elem_loc, "LocationCodeType", location_code_type
      # Some port names contain accent characters, which causes EDI translation errors.
      # Since they're not really needed, the simplest workaround is to just strip them out.
      add_element elem_loc, "Name", ActiveSupport::Inflector.transliterate(port.name)
      if port.address
        add_element elem_loc, "Address1", port.address.line_1
        add_element elem_loc, "Address2", port.address.line_2
        add_element elem_loc, "Address3", port.address.line_3
        add_element elem_loc, "City", port.address.city
        add_element elem_loc, "State", port.address.state
        add_element elem_loc, "PostalCode", port.address.postal_code
        add_element elem_loc, "Country", port.address.country&.iso_code
      end
      elem_loc
    end

    def send_xml doc, broker_inv
      sync_record = SyncRecord.find_or_build_sync_record broker_inv, SYNC_TRADING_PARTNER

      current_time = ActiveSupport::TimeZone["America/New_York"].now.strftime("%Y%m%d%H%M%S")
      filename_minus_suffix = "billing_invoice_#{broker_inv.invoice_number}_#{current_time}"

      Tempfile.open([filename_minus_suffix, ".xml"]) do |file|
        Attachment.add_original_filename_method(file, "#{filename_minus_suffix}.xml")
        write_xml(doc, file)
        file.rewind
        ftp_creds = connect_vfitrack_net("to_ecs/billing_invoice#{MasterSetup.get.production? ? "" : "_test"}/#{broker_inv.customer_number}")
        ftp_sync_file file, sync_record, ftp_creds
      end

      sync_record.sent_at = 1.second.ago
      sync_record.confirmed_at = 0.seconds.ago
      sync_record.save!

      nil
    end

end; end; end; end