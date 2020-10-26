require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/entry_parser_support'
require 'open_chain/custom_handler/vandegrift/cargowise_xml_support'

module OpenChain; module CustomHandler; module Vandegrift; class MaerskCargowiseEntryFileParser
  include OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::EntryParserSupport
  include OpenChain::CustomHandler::Vandegrift::CargowiseXmlSupport

  def self.integration_folder
    ["#{MasterSetup.get.system_code}/maersk_cw_universal_shipment"]
  end

  def self.parse_file data, log, opts={}
    self.new.parse(xml_document(data), opts)
  end

  def parse doc, opts={}
    doc = unwrap_document_root(doc)

    broker_reference = first_text doc, "UniversalShipment/Shipment/DataContext/DataSourceCollection/DataSource[Type='CustomsDeclaration']/Key"
    if broker_reference.blank?
      inbound_file.add_reject_message "Broker Reference is required."
      return
    end
    inbound_file.add_identifier :broker_reference, broker_reference

    import_country = get_import_country doc
    return unless import_country
    inbound_file.add_identifier :import_country, import_country.iso_code

    customer_number = get_customer_number import_country.iso_code, doc
    return unless customer_number.present?

    entry = nil
    Lock.acquire("Entry-Maersk-#{broker_reference}") { entry = Entry.where(broker_reference:broker_reference, source_system:Entry::CARGOWISE_SOURCE_SYSTEM).first_or_create! }
    Lock.with_lock_retry(entry) do
      inbound_file.set_identifier_module_info :broker_reference, Entry, entry.id

      populate_entry_header entry, import_country, customer_number, doc

      # Purge child table content.
      entry.destroy_commercial_invoices
      entry.containers.destroy_all

      entry_effective_date = import_country.iso_code == 'US' ? tariff_effective_date(entry) : nil
      xpath(doc, "UniversalShipment/Shipment/CommercialInfo/CommercialInvoiceCollection/CommercialInvoice") do |elem_inv|
        inv = entry.commercial_invoices.build
        populate_commercial_invoice inv, elem_inv, doc, import_country.iso_code
        # Cargowise cannot be counted upon to generate this XML with the invoice line elements sorted in
        # line number order.  We have to sort them ourselves.  The dupe line removal logic below relies upon
        # them being ordered sequentially.
        line_elems = xpath elem_inv, "CommercialInvoiceLineCollection/CommercialInvoiceLine"
        line_elems = line_elems.sort { |a, b| parse_integer(et(a, "LineNo")) <=> parse_integer(et(b, "LineNo")) }
        line_elems.each do |elem_line|
          parent_line_number = et elem_line, "ParentLineNo"
          condensed_line = false
          if parent_line_number.to_i == 0 || is_xvv_line?(elem_line)
            # This is a normal line, not a dupe.  XVV lines will include a parent line number, but they're cool to proceed.
            inv_line = inv.commercial_invoice_lines.build
            populate_commercial_invoice_line inv_line, elem_line, import_country, elem_inv, doc
          else
            condensed_line = true
            # Cargowise has a weird system limitation having to do with multiple HTS numbers that will create invoice
            # line copies to house the additional tariff number.  While we can mostly ignoreg the dupe line itself,
            # we need to write its tariff info to the "parent" line.
            inv_line = inv.commercial_invoice_lines.find { |cur_line| cur_line.line_number == parent_line_number.to_i }
            # Just skip this one if there's no matching parent.  We're assuming the documents are assembled sequentially.
            next unless inv_line
            # Another thing done is to update a handful of amount fields in the "parent" invoice line with values
            # pulled from the "child" XML line.  Everything else is considered to be dupe content.
            update_parent_line_amounts inv_line, elem_line
          end

          add_commercial_invoice_tariffs inv_line, elem_line, doc, import_country.iso_code, entry_effective_date, condensed_line
        end
      end

      # Populated by invoice-level data.
      entry.total_non_dutiable_amount = get_total_non_dutiable_amount entry
      entry.other_fees = get_total_other_fees entry
      entry.last_billed_date = get_last_billed_date entry
      if import_country.iso_code == 'US'
        entry.total_fees = get_us_total_fees entry
      end
      entry.total_duty_direct = is_deferred_duty?(entry) ? entry.total_duty_taxes_fees_amount : nil
      entry.po_numbers = get_po_numbers(entry).join(multi_value_separator)

      xpath(doc, "UniversalShipment/Shipment/ContainerCollection/Container") do |elem_cont|
        cont = entry.containers.build
        populate_container cont, elem_cont
      end

      xpath(doc, "UniversalShipment/Shipment/NoteCollection/Note") do |elem_note|
        note_text = et elem_note, "NoteText"
        if note_text.present?
          public_note = first_text(elem_note, "Visibility/Code") == "PUB" &&
                        first_text(elem_note, "Visibility/Description") == "CLIENT-VISIBLE"
          add_entry_comment entry, note_text, public_note
        end
      end

      process_special_tariffs entry

      if opts[:key] && opts[:bucket]
        entry.last_file_path = opts[:key]
        entry.last_file_bucket = opts[:bucket]
      end

      entry.save!
      entry.create_snapshot User.integration, nil, opts[:key]
      entry.broadcast_event(:save)

      inbound_file.add_info_message "Entry successfully processed."
      nil
    end

  end

  private
    def get_import_country xml
      import_country_code = nil
      port_code = first_text xml, "UniversalShipment/Shipment/DataContext/Company/Code"
      if port_code == 'YYZ'
        import_country_code = 'CA'
      elsif port_code == 'QMJ'
        import_country_code = 'US'
      end
      c = nil
      if import_country_code
        c = Country.where(iso_code:import_country_code).first
        if c.nil?
          # Indicates a setup or parser issue.  These ISO codes aren't pulled from the file.
          inbound_file.error_and_raise "Country record for ISO '#{import_country_code}' could not be found."
        end
      else
        inbound_file.add_reject_message "Could not determine Country of Origin.  Unknown code provided in 'UniversalShipment/Shipment/DataContext/Company/Code': '#{port_code.to_s}'."
      end
      c
    end

    def populate_entry_header entry, import_country, customer_number, xml
      entry_number = get_entry_number xml
      inbound_file.add_identifier :entry_number, entry_number unless entry_number.blank?
      entry.entry_number = entry_number

      entry.broker = get_broker(import_country.iso_code, entry_number)

      master_bills = get_master_bills xml
      inbound_file.add_identifier :master_bill, master_bills unless master_bills.empty?
      entry.master_bills_of_lading = master_bills.join(multi_value_separator)

      house_bills = get_house_bills xml
      inbound_file.add_identifier :house_bill, house_bills unless house_bills.empty?
      entry.house_bills_of_lading = house_bills.join(multi_value_separator)
      entry.customer_references = first_text xml, "UniversalShipment/Shipment/OwnerRef"
      entry.import_country_id = import_country.id

      entry.release_cert_message = get_release_cert_message xml
      entry.fda_message = first_text xml, "UniversalShipment/Shipment/EntryNumberCollection/EntryNumber[Type/Code='FDA']/EntryStatus/Description"
      entry.paperless_release = get_paperless_release xml
      entry.error_free_release = true
      entry.customer_number = customer_number
      entry.customer_name = get_customer_name import_country.iso_code, xml
      entry.importer_id = get_importer_id entry.customer_number, entry.customer_name
      entry.vendor_names = get_vendor_names_entry import_country.iso_code, xml
      entry.merchandise_description = first_text xml, "UniversalShipment/Shipment/GoodsDescription"

      entry.export_date = parse_date(first_text xml, "UniversalShipment/Shipment/DateCollection/Date[Type='LoadingDate']/Value")
      entry.direct_shipment_date = entry.export_date
      entry.docs_received_date = parse_date(first_text xml, "UniversalShipment/Shipment/CustomizedFieldCollection/CustomizedField[Key='Document Received Date']/Value")
      entry.first_it_date = parse_date(first_text xml, "UniversalShipment/Shipment/AddInfoCollection/AddInfo[Key='ITDate']/Value")
      entry.eta_date = parse_date(first_text xml, "UniversalShipment/Shipment/DateCollection/Date[Type='Arrival']/Value")
      entry.arrival_date = parse_datetime(first_text xml, "UniversalShipment/Shipment/AddInfoCollection/AddInfo[Key='EntryDate']/Value")
      entry.first_release_date = get_first_release_date xml
      entry.release_date = get_release_date import_country.iso_code, xml
      entry.freight_pickup_date = parse_datetime(first_text xml, "UniversalShipment/Shipment/ContainerCollection/Container/FCLWharfGateOut")
      entry.final_delivery_date = parse_datetime(first_text xml, "UniversalShipment/Shipment/ContainerCollection/Container/ArrivalCartageComplete")
      entry.free_date = parse_datetime(first_text xml, "UniversalShipment/Shipment/ContainerCollection/Container/FCLStorageCommences").try(:-, 1.day)
      entry.duty_due_date = parse_date(first_text xml, "UniversalShipment/Shipment/AddInfoCollection/AddInfo[Key='PaymentDueDate']/Value")
      entry.available_date = parse_datetime(first_text xml, "UniversalShipment/Shipment/ContainerCollection/Container/FCLAvailable")
      entry.import_date = parse_date(first_text xml, "UniversalShipment/Shipment/DateCollection/Date[Type='DischargeDate' or Type='Arrival']/Value")

      hold_release_setter = HoldReleaseSetter.new entry
      set_hold_date entry, :ams_hold_date, get_first_occurrence_date(xml, "UniversalShipment/Shipment/AdditionalBillCollection/AdditionalBill/AddInfoGroupCollection/AddInfoGroup[AddInfoCollection/AddInfo[Key='Code']/Value='51']/AddInfoCollection/AddInfo[Key='DispositionDate']/Value"), hold_release_setter, import_country.iso_code
      set_release_date entry, :ams_hold_release_date, get_last_occurrence_date(xml, "UniversalShipment/Shipment/AdditionalBillCollection/AdditionalBill/AddInfoGroupCollection/AddInfoGroup[AddInfoCollection/AddInfo[Key='Code']/Value='54']/AddInfoCollection/AddInfo[Key='DispositionDate']/Value"), hold_release_setter, import_country.iso_code
      set_hold_date entry, :aphis_hold_date, get_first_occurrence_date(xml, "UniversalShipment/Shipment/AdditionalBillCollection/AdditionalBill/AddInfoGroupCollection/AddInfoGroup[AddInfoCollection/AddInfo[Key='Code']/Value='52']/AddInfoCollection/AddInfo[Key='DispositionDate']/Value"), hold_release_setter, import_country.iso_code
      set_release_date entry, :aphis_hold_release_date, get_last_occurrence_date(xml, "UniversalShipment/Shipment/AdditionalBillCollection/AdditionalBill/AddInfoGroupCollection/AddInfoGroup[AddInfoCollection/AddInfo[Key='Code']/Value='55']/AddInfoCollection/AddInfo[Key='DispositionDate']/Value"), hold_release_setter, import_country.iso_code
      set_hold_date entry, :cbp_hold_date, get_first_occurrence_date(xml, "UniversalShipment/Shipment/AdditionalBillCollection/AdditionalBill/AddInfoGroupCollection/AddInfoGroup[AddInfoCollection/AddInfo[Key='Code']/Value='53']/AddInfoCollection/AddInfo[Key='DispositionDate']/Value"), hold_release_setter, import_country.iso_code
      set_release_date entry, :cbp_hold_release_date, get_last_occurrence_date(xml, "UniversalShipment/Shipment/AdditionalBillCollection/AdditionalBill/AddInfoGroupCollection/AddInfoGroup[AddInfoCollection/AddInfo[Key='Code']/Value='56']/AddInfoCollection/AddInfo[Key='DispositionDate']/Value"), hold_release_setter, import_country.iso_code
      set_hold_date entry, :cbp_intensive_hold_date, get_first_occurrence_date(xml, "UniversalShipment/Shipment/AddInfoGroupCollection/AddInfoGroup[Type/Code='UDP' and AddInfoCollection/AddInfo[Key='Code']/Value='03']/AddInfoCollection/AddInfo[Key='DispositionDate']/Value"), hold_release_setter, import_country.iso_code
      # Behaves different from other hold release dates.  In this case, we've been instructed to set the value
      # only when the hold date has a value, implying that Cargowise can send a release without the hold.
      if entry.cbp_intensive_hold_date.present?
        set_release_date entry, :cbp_intensive_hold_release_date, get_last_occurrence_date(xml, "UniversalShipment/Shipment/AddInfoGroupCollection/AddInfoGroup[Type/Code='UDP' and AddInfoCollection/AddInfo[Key='Code']/Value='98']/AddInfoCollection/AddInfo[Key='DispositionDate']/Value"), hold_release_setter, import_country.iso_code
      end
      # Note that these USDA hold/release dates are the same value as APHIS hold/release date.  This might wind up being wrong, but it was done intentionally.
      set_hold_date entry, :usda_hold_date, get_first_occurrence_date(xml, "UniversalShipment/Shipment/AdditionalBillCollection/AdditionalBill/AddInfoGroupCollection/AddInfoGroup[AddInfoCollection/AddInfo[Key='Code']/Value='52']/AddInfoCollection/AddInfo[Key='DispositionDate']/Value"), hold_release_setter, import_country.iso_code
      set_release_date entry, :usda_hold_release_date, get_last_occurrence_date(xml, "UniversalShipment/Shipment/AdditionalBillCollection/AdditionalBill/AddInfoGroupCollection/AddInfoGroup[AddInfoCollection/AddInfo[Key='Code']/Value='55']/AddInfoCollection/AddInfo[Key='DispositionDate']/Value"), hold_release_setter, import_country.iso_code
      set_release_date entry, :one_usg_date, parse_datetime(first_text xml, "UniversalShipment/Shipment/AddInfoGroupCollection/AddInfoGroup[Type/Code='UDP' and AddInfoCollection/AddInfo[Key='Code']/Value='01']/AddInfoCollection/AddInfo[Key='DispositionDate']/Value"), hold_release_setter, import_country.iso_code

      if import_country.iso_code == 'US'
        hold_release_setter.set_summary_hold_date
        hold_release_setter.set_summary_hold_release_date
      end

      entry.last_exported_from_source = Time.zone.now

      entry.entry_port_code = get_entry_port_code import_country.iso_code, xml
      entry.lading_port_code = get_lading_port_code import_country.iso_code, xml
      entry.unlading_port_code = get_unlading_port_code import_country.iso_code, xml

      if import_country.iso_code == 'US'
        entry.destination_state = first_text xml, "UniversalShipment/Shipment/AddInfoCollection/AddInfo[Key='DestinationState']/Value"
      end
      entry.entry_type = get_entry_type import_country.iso_code, xml
      if import_country.iso_code == 'US'
        entry.mfids = unique_values xml, "UniversalShipment/Shipment/CommercialInfo/CommercialInvoiceCollection/CommercialInvoice/CommercialInvoiceLineCollection/CommercialInvoiceLine/OrganizationAddressCollection/OrganizationAddress[AddressType='Manufacturer']/RegistrationNumberCollection/RegistrationNumber[Type/Code='MID']/Value", as_csv:true, csv_separator:multi_value_separator
      end
      entry.export_country_codes = get_export_country_codes import_country.iso_code, xml
      entry.origin_country_codes = get_origin_country_codes import_country.iso_code, xml

      if import_country.iso_code == 'US'
        entry.special_program_indicators = unique_values xml, "UniversalShipment/Shipment/CommercialInfo/CommercialInvoiceCollection/CommercialInvoice/CommercialInvoiceLineCollection/CommercialInvoiceLine/AddInfoCollection/AddInfo[Key='SPI']/Value", as_csv:true, csv_separator:multi_value_separator
      end
      entry.voyage = first_text xml, "UniversalShipment/Shipment/VoyageFlightNo"
      entry.location_of_goods = first_text xml, "UniversalShipment/Shipment/AddInfoCollection/AddInfo[Key='US_NKLocationOfGoods']/Value"
      entry.ult_consignee_name = get_ult_consignee_name import_country.iso_code, xml
      entry.transport_mode_code = get_transport_mode_code import_country.iso_code, xml
      entry.carrier_code = get_carrier_code import_country.iso_code, xml
      entry.carrier_name = get_carrier_name import_country.iso_code, xml

      entry.vessel = get_vessel xml, entry

      entry.sub_house_bills_of_lading = unique_values xml, "UniversalShipment/Shipment/AdditionalBillCollection/AdditionalBill[BillType/Code='SWB']/BillNumber", as_csv:true, csv_separator:multi_value_separator
      entry.it_numbers = unique_values xml, "UniversalShipment/Shipment/AdditionalBillCollection/AdditionalBill/AddInfoGroupCollection/AddInfoGroup/AddInfoCollection/AddInfo[Key='ITNumber']/Value", as_csv:true, csv_separator:multi_value_separator
      entry.container_numbers = unique_values xml, "UniversalShipment/Shipment/ContainerCollection/Container/ContainerNumber", as_csv:true, csv_separator:multi_value_separator
      entry.container_sizes = unique_values xml, "UniversalShipment/Shipment/ContainerCollection/Container/ContainerType/Code", as_csv:true, csv_separator:multi_value_separator
      entry.fcl_lcl = unique_values xml, "UniversalShipment/Shipment/ContainerCollection/Container/FCL_LCL_AIR/Code", as_csv:true, csv_separator:multi_value_separator
      entry.ult_consignee_code = get_ult_consignee_code import_country.iso_code, xml
      entry.importer_tax_id = get_importer_tax_id import_country.iso_code, xml
      entry.division_number = first_text xml, "UniversalShipment/Shipment/Branch/Code"
      entry.recon_flags = first_text xml, "UniversalShipment/Shipment/AddInfoCollection/AddInfo[Key='OtherReconIndicator']/Value"
      entry.bond_type = first_text xml, "UniversalShipment/Shipment/AddInfoCollection/AddInfo[Key='BondType']/Value"

      if import_country.iso_code == 'CA'
        entry.total_fees = get_canada_total_fees xml
      end
      entry.total_duty = get_total_duty import_country.iso_code, xml
      entry.total_taxes = total_value xml, "UniversalShipment/Shipment/EntryHeaderCollection/EntryHeader/EntryHeaderChargeCollection/EntryHeaderCharge[Type/Code='016' or Type/Code='022' or Type/Code='018' or Type/Code='017']/Amount"
      entry.cotton_fee = parse_decimal(first_text xml, "UniversalShipment/Shipment/EntryHeaderCollection/EntryHeader/EntryHeaderChargeCollection/EntryHeaderCharge[Type/Code='056']/Amount")
      entry.hmf = parse_decimal(first_text xml, "UniversalShipment/Shipment/EntryHeaderCollection/EntryHeader/EntryHeaderChargeCollection/EntryHeaderCharge[Type/Code='501']/Amount")
      entry.mpf = parse_decimal(first_text xml, "UniversalShipment/Shipment/EntryHeaderCollection/EntryHeader/EntryHeaderChargeCollection/EntryHeaderCharge[Type/Code='499']/Amount")
      entry.entered_value = get_total_entered_value import_country.iso_code, xml
      entry.total_invoiced_value = total_value xml, "UniversalShipment/Shipment/CommercialInfo/CommercialInvoiceCollection/CommercialInvoice/InvoiceAmount"
      entry.gross_weight = get_gross_weight xml
      entry.total_units = total_value xml, "UniversalShipment/Shipment/CommercialInfo/CommercialInvoiceCollection/CommercialInvoice/CommercialInvoiceLineCollection/CommercialInvoiceLine/InvoiceQuantity"
      entry.total_units_uoms = unique_values xml, "UniversalShipment/Shipment/CommercialInfo/CommercialInvoiceCollection/CommercialInvoice/CommercialInvoiceLineCollection/CommercialInvoiceLine/InvoiceQuantityUnit/Code", as_csv:true, csv_separator:multi_value_separator
      entry.total_packages = get_total_packages import_country.iso_code, xml
      entry.total_packages_uom = get_total_packages_uom import_country.iso_code, xml

      entry.split_shipment = parse_boolean(first_text xml, "UniversalShipment/Shipment/AdditionalBillCollection/AdditionalBill/AddInfoCollection/AddInfo[Key='SESplitShip']/Value")
      entry.split_release_option = first_text xml, "UniversalShipment/Shipment/AddInfoCollection/AddInfo[Key='SESplitRel']/Value"
      entry.summary_line_count = get_entry_summary_line_count import_country.iso_code, xml
      entry.pay_type = parse_integer(first_text xml, "UniversalShipment/Shipment/AddInfoCollection/AddInfo[Key='PaymentType']/Value")
      entry.daily_statement_number = first_text xml, "UniversalShipment/Shipment/AddInfoCollection/AddInfo[Key='StatementNumber']/Value"
      entry.daily_statement_due_date = parse_date(first_text xml, "UniversalShipment/Shipment/AddInfoCollection/AddInfo[Key='PaymentDueDate']/Value")
      entry.daily_statement_approved_date = parse_date(first_text xml, "UniversalShipment/Shipment/AddInfoCollection/AddInfo[Key='PaymentDate']/Value")
      entry.monthly_statement_due_date = parse_date(first_text xml, "UniversalShipment/Shipment/EntryHeaderCollection/EntryHeader/AddInfoCollection/AddInfo[Key='CollectionDate']/Value")

      if import_country.iso_code == 'CA'
        entry.cadex_sent_date = parse_datetime(first_text xml, "UniversalShipment/Shipment/EntryHeaderCollection/EntryHeader[Type/Code='B3C']/EntrySubmittedDate")
        entry.total_gst = get_total_gst xml
        entry.total_duty_gst = parse_decimal(first_text xml, "UniversalShipment/Shipment/EntryHeaderCollection/EntryHeader[Type/Code='B3C']/TotalAmountPaid")
        entry.origin_state_codes = unique_values xml, "UniversalShipment/Shipment/CommercialInfo/CommercialInvoiceCollection/CommercialInvoice/CommercialInvoiceLineCollection/CommercialInvoiceLine/StateOfOrigin/Code", as_csv:true, csv_separator:multi_value_separator
        entry.export_state_codes = unique_values xml, "UniversalShipment/Shipment/CommercialInfo/CommercialInvoiceCollection/CommercialInvoice/AddInfoCollection/AddInfo[Key='USStateOfExport']/Value", as_csv:true, csv_separator:multi_value_separator
        entry.cargo_control_number = first_text xml, "UniversalShipment/Shipment/CustomsReferenceCollection/CustomsReference[Type/Code='CCN']/Reference"
        entry.ship_terms = first_text xml, "UniversalShipment/Shipment/ShipmentIncoTerm/Code"
        entry.us_exit_port_code = first_text xml, "UniversalShipment/Shipment/CommercialInfo/CommercialInvoiceCollection/CommercialInvoice/AddInfoCollection/AddInfo[Key='USPortOfExit']/Value"
        entry.release_type = first_text xml, "UniversalShipment/Shipment/AddInfoCollection/AddInfo[Key='ServiceOption']/Value"
        entry.employee_name = first_text xml, "UniversalShipment/Shipment/CustomsBroker/Code"
      end
    end

    def get_entry_number xml
      entry_filer_code = first_text xml, "UniversalShipment/Shipment/AddInfoCollection/AddInfo[Key='EntryFilerCode']/Value"
      entry_number = first_text xml, "UniversalShipment/Shipment/EntryNumberCollection/EntryNumber/Number"
      (entry_filer_code.to_s) + (entry_number.to_s)
    end

    # The bills of lading returned contain a potential mixture of UNIQUE values found under two bill types.
    def get_master_bills xml
      hwb_parents = get_bills_of_lading xml, "UniversalShipment/Shipment/AdditionalBillCollection/AdditionalBill[BillType/Code='HWB']", "ParentBillNumber", "ParentBillIssuerSCAC"
      mwbs = get_bills_of_lading xml, "UniversalShipment/Shipment/AdditionalBillCollection/AdditionalBill[BillType/Code='MWB']", "BillNumber", "UI_NKBillIssuerSCAC"
      (hwb_parents + mwbs).uniq
    end

    def get_bills_of_lading xml, bol_base_xpath, bill_field_name, scac_key
      bol_arr = []
      xpath(xml, bol_base_xpath) do |elem_bol|
        bol = et(elem_bol, bill_field_name).to_s.strip
        next if bol.blank?

        bol_prefix = first_text(elem_bol, "AddInfoCollection/AddInfo[Key='#{scac_key}']/Value").to_s.strip
        # Checking for existing SCAC prefix before appending SCAC.  This prevents hideous, double-SCAC'ed
        # monstrosities like "ABCDABCD12345678".
        bol_arr << (bol.starts_with?(bol_prefix) ? bol : (bol_prefix + bol))
      end
      bol_arr
    end

    def get_house_bills xml
      hwbs = get_bills_of_lading xml, "UniversalShipment/Shipment/AdditionalBillCollection/AdditionalBill[BillType/Code='HWB']", "BillNumber", "UI_NKBillIssuerSCAC"
      hwbs.uniq
    end

    def get_release_cert_message xml
      v = first_text xml, "UniversalShipment/Shipment/EntryHeaderCollection/EntryHeader/EntryReleaseDate"
      if v.blank?
        v = first_text xml, "UniversalShipment/Shipment/AddInfoGroupCollection/AddInfoGroup[Type/Code='UDP' and AddInfoCollection/AddInfo[Key='Code']/Value='98']/AddInfoCollection/AddInfo[Key='DispositionDate']/Value"
      end
      v.present? ? "RELEASED" : nil
    end

    def get_customer_number import_country_iso, xml
      v = nil
      if import_country_iso == 'US'
        v = first_text xml, "UniversalShipment/Shipment/OrganizationAddressCollection/OrganizationAddress[AddressType='ImporterOfRecord']/OrganizationCode"
      elsif import_country_iso == 'CA'
        v = first_text xml, "UniversalShipment/Shipment/OrganizationAddressCollection/OrganizationAddress[AddressType='ImporterDocumentaryAddress']/OrganizationCode"
      end
      if v.blank?
        inbound_file.add_reject_message "Customer Number is required."
      end
      v
    end

    # Defaults to true unless a PaperlessEntry AddInfo is provided.
    def get_paperless_release xml
      paperless_entry = first_text xml, "UniversalShipment/Shipment/AddInfoCollection/AddInfo[Key='PaperlessEntry']/Value"
      paperless_entry.blank? || parse_boolean(paperless_entry)
    end

    def get_customer_name import_country_iso, xml
      v = nil
      if import_country_iso == 'US'
        v = first_text xml, "UniversalShipment/Shipment/OrganizationAddressCollection/OrganizationAddress[AddressType='ImporterOfRecord']/CompanyName"
      elsif import_country_iso == 'CA'
        v = first_text xml, "UniversalShipment/Shipment/OrganizationAddressCollection/OrganizationAddress[AddressType='ImporterDocumentaryAddress']/CompanyName"
      end
      v
    end

    def get_importer_id customer_number, customer_name
      system_identifier = SystemIdentifier.where(system: "Cargowise", code: customer_number).first
      company = system_identifier&.company
      if system_identifier.nil?
        Lock.acquire("Company-Cargowise-#{customer_number}") do
          system_identifier = SystemIdentifier.where(system: "Cargowise", code: customer_number).first_or_create!
          company = system_identifier.company
          if company.nil?
            company = Company.create!(importer: true, name: customer_name)
            company.system_identifiers << system_identifier
          end
        end
      end
      company&.id
    end

    def get_vendor_names_entry import_country_iso, xml
      v = nil
      if import_country_iso == 'US'
        v = unique_values xml, "UniversalShipment/Shipment/CommercialInfo/CommercialInvoiceCollection/CommercialInvoice/CommercialInvoiceLineCollection/CommercialInvoiceLine/OrganizationAddressCollection/OrganizationAddress[AddressType='Manufacturer']/CompanyName", as_csv:true, csv_separator:multi_value_separator
      elsif import_country_iso == 'CA'
        v = unique_values xml, "UniversalShipment/Shipment/CommercialInfo/CommercialInvoiceCollection/CommercialInvoice/Supplier[AddressType='Supplier']/CompanyName", as_csv:true, csv_separator:multi_value_separator
      end
      # Vendor names can contain commas, which results in quotes in the unique_values output.  Since this is just
      # going into a string field, those quotes should be removed.
      v&.gsub("\"", "")
    end

    def get_vendor_name_invoice import_country_iso, xml
      v = nil
      if import_country_iso == 'US'
        v = first_text xml, "CommercialInvoiceLineCollection/CommercialInvoiceLine/OrganizationAddressCollection/OrganizationAddress[AddressType='Manufacturer']/CompanyName"
      elsif import_country_iso == 'CA'
        v = first_text xml, "Supplier[AddressType='Supplier']/CompanyName"
      end
      v
    end

    def get_broker import_country_iso, entry_number
      b = nil
      if import_country_iso == 'US'
        b = find_us_broker(entry_number)
      elsif import_country_iso == 'CA'
        b = find_ca_broker(entry_number)
      end
      b
    end

    def parse_date date_str
      parse_datetime(date_str)&.to_date
    end

    def parse_datetime date_str
      date_str.present? ? time_zone.parse(date_str) : nil
    end

    def time_zone
      # All times provided in the document are assumed to be from this zone.
      @zone ||= ActiveSupport::TimeZone["America/New_York"]
    end

    def parse_decimal dec_str, decimal_places: 2, rounding_mode: BigDecimal::ROUND_HALF_UP
      v = dec_str.try(:to_d) || BigDecimal.new(0)
      v.round(decimal_places, rounding_mode)
    end

    # Rounds to nearest whole number.
    def parse_integer int_str
      parse_decimal(int_str, decimal_places: 0).to_i
    end

    # Sums the values as decimals, but returns the result as an integer, rounded to the nearest whole number.
    def total_value_integer xml, xpath
      total_value(xml, xpath).round(0, BigDecimal::ROUND_HALF_UP).to_i
    end

    def parse_boolean bool_str
      bool_str.try(:upcase) == "Y"
    end

    def get_first_release_date xml
      d = parse_datetime(first_text xml, "UniversalShipment/Shipment/DateCollection/Date[Type='EntryAuthorisation']/Value")
      if d.nil?
        d = parse_datetime(first_text xml, "UniversalShipment/Shipment/CustomizedFieldCollection/CustomizedField[Key='OutportBrokerReleaseDate']/Value")
      end
      d
    end

    def get_release_date import_country_iso, xml
      d = nil
      if import_country_iso == 'US'
        d = parse_datetime(first_text xml, "UniversalShipment/Shipment/EntryHeaderCollection/EntryHeader/EntryReleaseDate")
        if d.nil?
          d = get_last_occurrence_date xml, "UniversalShipment/Shipment/AddInfoGroupCollection/AddInfoGroup[Type/Code='UDP' and AddInfoCollection/AddInfo[Key='Code']/Value='98']/AddInfoCollection/AddInfo[Key='ReleaseDate']/Value"
        end
      elsif import_country_iso == 'CA'
        d = parse_datetime(first_text xml, "UniversalShipment/Shipment/DateCollection/Date[Type='EntryAuthorisation']/Value")
      end
      # This applies to both countries.
      if d.nil?
        d = parse_datetime(first_text xml, "UniversalShipment/Shipment/CustomizedFieldCollection/CustomizedField[Key='OutportBrokerReleaseDate']/Value")
      end
      d
    end

    # "Map from the last occurrence" has been interpreted to mean the latest date of this type in the
    # document (and that there can be multiple matches).
    def get_last_occurrence_date xml, xpath
      get_multiple_occurrence_date(xml, xpath) { |cur_d, d| cur_d > d }
    end

    def set_hold_date entry, date_field, hold_date, hold_release_setter, import_country_iso
      set_hold_or_release_date entry, date_field, hold_date, hold_release_setter, import_country_iso do |hold_release_setter, event_date, date_field|
        hold_release_setter.set_any_hold_date event_date, date_field
      end
    end

    def set_release_date entry, date_field, release_date, hold_release_setter, import_country_iso
      set_hold_or_release_date entry, date_field, release_date, hold_release_setter, import_country_iso do |hold_release_setter, event_date, date_field|
        hold_release_setter.set_any_hold_release_date event_date, date_field
      end
    end

    def set_hold_or_release_date entry, date_field, event_date, hold_release_setter, import_country_iso
      if import_country_iso == 'US'
        yield hold_release_setter, event_date, date_field
      else
        entry.public_send((date_field.to_s + "=").to_sym, event_date)
      end
    end

    # "Map from the last occurrence" has been interpreted to mean the earliest date of this type in the
    # document (and that there can be multiple matches).
    def get_first_occurrence_date xml, xpath
      get_multiple_occurrence_date(xml, xpath) { |cur_d, d| cur_d < d }
    end

    # Deals with cases where xpath evaluation can retrieve multiple instances of a given date.  How this
    # is to be handled should be provided via a block returning a boolean value.
    def get_multiple_occurrence_date xml, xpath
      d = nil
      date_arr = unique_values xml, xpath
      date_arr.each do |cur|
        cur_d = parse_datetime cur
        if d.nil? || yield(cur_d, d)
          d = cur_d
        end
      end
      d
    end

    def get_entry_port_code import_country_iso, xml
      v = nil
      if import_country_iso == 'US'
        v = first_text xml, "UniversalShipment/Shipment/AddInfoCollection/AddInfo[Key='SchDEntry']/Value"
      elsif import_country_iso == 'CA'
        v = first_text xml, "UniversalShipment/Shipment/AddInfoCollection/AddInfo[Key='PortOfClearance']/Value"
      end
      v
    end

    def get_lading_port_code import_country_iso, xml
      v = nil
      if import_country_iso == 'US'
        v = first_text xml, "UniversalShipment/Shipment/AddInfoCollection/AddInfo[Key='SchDLoading']/Value"
      elsif import_country_iso == 'CA'
        v = first_text xml, "UniversalShipment/Shipment/PortOfLoading/Code"
      end
      v
    end

    def get_unlading_port_code import_country_iso, xml
      v = nil
      if import_country_iso == 'US'
        v = first_text xml, "UniversalShipment/Shipment/AddInfoCollection/AddInfo[Key='SchDArrival']/Value"
      elsif import_country_iso == 'CA'
        v = first_text xml, "UniversalShipment/Shipment/PortOfDischarge/Code"
        if v.blank?
          v = first_text xml, "UniversalShipment/Shipment/AddInfoCollection/AddInfo[Key='UnladingOffice']/Value"
        end
      end
      v
    end

    def get_entry_type import_country_iso, xml
      v = nil
      if import_country_iso == 'US'
        v = first_text xml, "UniversalShipment/Shipment/AddInfoCollection/AddInfo[Key='EntryType']/Value"
      elsif import_country_iso == 'CA'
        v = first_text xml, "UniversalShipment/Shipment/MessageSubType/Code"
      end
      v
    end

    def get_export_country_codes import_country_iso, xml
      v = nil
      if import_country_iso == 'US'
        v = unique_values xml, "UniversalShipment/Shipment/CommercialInfo/CommercialInvoiceCollection/CommercialInvoice/CommercialInvoiceLineCollection/CommercialInvoiceLine/AddInfoCollection/AddInfo[Key='UC_NKCountryOfExport']/Value", as_csv:true, csv_separator:multi_value_separator
      elsif import_country_iso == 'CA'
        v = unique_values xml, "UniversalShipment/Shipment/CommercialInfo/CommercialInvoiceCollection/CommercialInvoice/CommercialInvoiceLineCollection/CommercialInvoiceLine/CountryOfOrigin/Code", as_csv:true, csv_separator:multi_value_separator
      end
      v
    end

    def get_origin_country_codes import_country_iso, xml
      v = nil
      if import_country_iso == 'US'
        v = unique_values xml, "UniversalShipment/Shipment/CommercialInfo/CommercialInvoiceCollection/CommercialInvoice/CommercialInvoiceLineCollection/CommercialInvoiceLine/AddInfoCollection/AddInfo[Key='UC_NKCountryOfOrigin']/Value", as_csv:true, csv_separator:multi_value_separator
      elsif import_country_iso == 'CA'
        v = unique_values xml, "UniversalShipment/Shipment/CommercialInfo/CommercialInvoiceCollection/CommercialInvoice/CommercialInvoiceLineCollection/CommercialInvoiceLine/CountryOfOrigin/Code", as_csv:true, csv_separator:multi_value_separator
      end
      v
    end

    def get_vessel xml, entry
      # CW air shipments do not have a vessel name value.  We're substituting carrier code in its place.
      entry.air? ? entry.carrier_code : first_text(xml, "UniversalShipment/Shipment/VesselName")
    end

    def get_ult_consignee_name import_country_iso, xml
      v = nil
      if import_country_iso == 'US'
        v = first_text xml, "UniversalShipment/Shipment/OrganizationAddressCollection/OrganizationAddress[AddressType='UltimateConsignee']/CompanyName"
      elsif import_country_iso == 'CA'
        v = first_text xml, "UniversalShipment/Shipment/OrganizationAddressCollection/OrganizationAddress[AddressType='ImporterDocumentaryAddress']/CompanyName"
      end
      v
    end

    def get_transport_mode_code import_country_iso, xml
      transport_mode = first_text xml, "UniversalShipment/Shipment/TransportMode/Code"
      container_mode = first_text xml, "UniversalShipment/Shipment/CustomsContainerMode/Code"
      cw_code = transport_mode.to_s + container_mode.to_s

      v = nil
      if import_country_iso == 'US'
        v = DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:cw_code).first.try(:value)
      elsif import_country_iso == 'CA'
        v = DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:cw_code).first.try(:value)
      end
      v
    end

    def get_carrier_code import_country_iso, xml
      v = nil
      if import_country_iso == 'US'
        v = first_text xml, "UniversalShipment/Shipment/AddInfoCollection/AddInfo[Key='MasterWayBillIssuerSCAC']/Value"
        if v.blank?
          v = first_text xml, "UniversalShipment/Shipment/AddInfoCollection/AddInfo[Key='WayBillIssuerSCAC']/Value"
        end
      elsif import_country_iso == 'CA'
        v = first_text xml, "UniversalShipment/Shipment/AddInfoCollection/AddInfo[Key='CarrierCode']/Value"
      end
      v
    end

    def get_carrier_name import_country_iso, xml
      v = nil
      if import_country_iso == 'US'
        v = first_text xml, "UniversalShipment/Shipment/TransportLegCollection/TransportLeg/Carrier[AddressType='Carrier']/CompanyName"
      elsif import_country_iso == 'CA'
        v = first_text xml, "UniversalShipment/Shipment/AddInfoCollection/AddInfo[Key='CarrierName']/Value"
      end
    end

    def get_ult_consignee_code import_country_iso, xml
      v = nil
      if import_country_iso == 'US'
        v = first_text xml, "UniversalShipment/Shipment/OrganizationAddressCollection/OrganizationAddress[AddressType='UltimateConsignee']/OrganizationCode"
      elsif import_country_iso == 'CA'
        v = first_text xml, "UniversalShipment/Shipment/OrganizationAddressCollection/OrganizationAddress[AddressType='ImporterDocumentaryAddress']/OrganizationCode"
      end
      v
    end

    def get_importer_tax_id import_country_iso, xml
      v = nil
      if import_country_iso == 'US'
        v = first_text xml, "UniversalShipment/Shipment/OrganizationAddressCollection/OrganizationAddress[AddressType='ImporterOfRecord']/GovRegNum"
      elsif import_country_iso == 'CA'
        v = first_text xml, "UniversalShipment/Shipment/OrganizationAddressCollection/OrganizationAddress[AddressType='ImporterDocumentaryAddress']/GovRegNum"
      end
      v
    end

    def get_canada_total_fees xml
      amount_paid = parse_decimal(first_text xml, "UniversalShipment/Shipment/EntryHeaderCollection/EntryHeader[Type/Code='B3C']/TotalAmountPaid")
      total_duty = total_value xml, "UniversalShipment/Shipment/EntryHeaderCollection/EntryHeader/EntryLineCollection/EntryLine/EntryLineChargeCollection/EntryLineCharge[Type/Code='DTY']/Amount"
      total = amount_paid - total_duty
      total
    end

    def get_total_duty import_country_iso, xml
      total = BigDecimal.new(0)
      if import_country_iso == 'US'
        total = total_value xml, "UniversalShipment/Shipment/EntryHeaderCollection/EntryHeader/EntryLineCollection/EntryLine/EntryLineChargeCollection/EntryLineCharge[Type/Code='DTY']/Amount"
      elsif import_country_iso == 'CA'
        total_gst = get_total_gst xml
        total_duty_gst = parse_decimal(first_text xml, "UniversalShipment/Shipment/EntryHeaderCollection/EntryHeader[Type/Code='B3C']/TotalAmountPaid")
        total = total_duty_gst - total_gst
      end
      total
    end

    def get_total_gst xml
      total_value xml, "UniversalShipment/Shipment/CommercialInfo/CommercialInvoiceCollection/CommercialInvoice/CommercialInvoiceLineCollection/CommercialInvoiceLine/AddInfoGroupCollection/AddInfoGroup/AddInfoCollection[AddInfo/Key='RateType' and AddInfo/Value='V'][AddInfo/Key='TaxType' and AddInfo/Value='GST']/AddInfo[Key='Amount']/Value"
    end

    def is_deferred_duty? entry
      entry.broker_invoices.find { |brin| OpenChain::CustomHandler::Vandegrift::MaerskCargowiseBrokerInvoiceFileParser.is_deferred_duty? brin }.present?
    end

    def get_total_entered_value import_country_iso, xml
      total = BigDecimal.new(0)
      if import_country_iso == 'US'
        total = total_value xml, "UniversalShipment/Shipment/CommercialInfo/CommercialInvoiceCollection/CommercialInvoice/CommercialInvoiceLineCollection/CommercialInvoiceLine[ParentLineNo='0']/CustomsValue"
      elsif import_country_iso == 'CA'
        total = total_value xml, "UniversalShipment/Shipment/EntryHeaderCollection/EntryHeader[Type/Code='B3C']/EntryLineCollection/EntryLine/CustomsValue"
      end
      total
    end

    def get_gross_weight xml
      # Gross weight is an integer field for some reason.
      v = parse_integer(first_text xml, "UniversalShipment/Shipment/TotalWeight")
      if v == 0
        v = total_value_integer xml, "UniversalShipment/Shipment/CommercialInfo/CommercialInvoiceCollection/CommercialInvoice/Weight"
      end
      v
    end

    def get_total_packages import_country_iso, xml
      v = 0
      if import_country_iso == 'US'
        v = parse_integer(first_text xml, "UniversalShipment/Shipment/TotalNoOfPacks")
      elsif import_country_iso == 'CA'
        v = parse_integer(first_text xml, "UniversalShipment/Shipment/OuterPacks")
      end
      v
    end

    def get_total_packages_uom import_country_iso, xml
      v = nil
      if import_country_iso == 'US'
        v = first_text xml, "UniversalShipment/Shipment/TotalNoOfPacksPackageType/Code"
      elsif import_country_iso == 'CA'
        v = first_text xml, "UniversalShipment/Shipment/OuterPacksPackageType/Code"
      end
      v
    end

    def get_entry_summary_line_count import_country_iso, xml
      val = 0
      if import_country_iso == 'US'
        val = unique_values(xml, "UniversalShipment/Shipment/EntryHeaderCollection/EntryHeader/EntryLineCollection/EntryLine/LineNumber").max_by { |x| x.to_i }.to_i
      elsif import_country_iso == 'CA'
        val = xpath(xml, "UniversalShipment/Shipment/EntryHeaderCollection/EntryHeader[Type/Code='B3C']/EntryLineCollection/EntryLine").length
      end
      val
    end

    def populate_commercial_invoice inv, elem, doc, import_country_iso
      inv.invoice_number = et elem, "InvoiceNumber"
      # Invoice-level MID is the first line-level MID that is not empty.
      inv.mfid = first_text elem, "CommercialInvoiceLineCollection/CommercialInvoiceLine/OrganizationAddressCollection/OrganizationAddress[AddressType='Manufacturer']/RegistrationNumberCollection/RegistrationNumber[Type/Code='MID' and normalize-space(Value) != '']/Value"
      inv.invoice_date = parse_date(et elem, "InvoiceDate")
      # Gross weight is an integer field for some reason.
      inv.gross_weight = parse_integer(et elem, "Weight")
      inv.country_origin_code = first_text elem, "AddInfoCollection/AddInfo[Key='UC_NKCountryOfOrigin']/Value"
      inv.invoice_value = parse_decimal(et elem, "InvoiceAmount")
      inv.total_charges = parse_decimal(et elem, "CommercialChargeCollection/CommercialCharge[ChargeType/Code='OFT']/Amount")
      if foreign_currency? first_text(elem, "InvoiceCurrency/Code"), import_country_iso
        invoice_value = parse_decimal(et elem, "InvoiceAmount")
        inv.invoice_value = invoice_value
        inv.invoice_value_foreign = convert_foreign_invoice_value parse_decimal(et(elem, "AgreedExchangeRate"), decimal_places:6), invoice_value
      end
      inv.currency = first_text elem, "InvoiceCurrency/Code"
      inv.total_quantity = parse_decimal(et elem, "NoOfPacks")
      inv.total_quantity_uom = first_text doc, "UniversalShipment/Shipment/TotalNoOfPacksPackageType/Code"
      inv.exchange_rate = parse_decimal(et(elem, "AgreedExchangeRate"), decimal_places:6)
      inv.non_dutiable_amount = total_value elem, "CommercialChargeCollection/CommercialCharge[IsDutiable='false' and IsNotIncludedInInvoice='false']/Amount"
      inv.master_bills_of_lading = get_invoice_master_bills_of_lading elem
      inv.entered_value_7501 = total_value_integer elem, "CommercialInvoiceLineCollection/CommercialInvoiceLine[ParentLineNo='0']/CustomsValue"
      inv.vendor_name = get_vendor_name_invoice import_country_iso, elem
    end

    def foreign_currency? currency_code, import_country_iso
      (import_country_iso == 'US' && currency_code != 'USD') || (import_country_iso == 'CA' && currency_code != 'CAD')
    end

    def convert_foreign_invoice_value exchange_rate, value
      (exchange_rate * value).round(2, BigDecimal::ROUND_HALF_UP)
    end

    def get_invoice_master_bills_of_lading elem
      val = first_text elem, "CustomizedFieldCollection/CustomizedField[Key='BOL Number']/Value"
      if val.blank?
        val = et elem, "BillNumber"
      end
      val
    end

    def is_xvv_line? elem_line
      xpath(elem_line, "AddInfoCollection/AddInfo[Key='SetInd']").length > 0
    end

    def populate_commercial_invoice_line inv_line, elem, import_country, elem_invoice, elem_root
      inv_line.line_number = parse_integer(et elem, "LineNo")
      inv_line.po_number = et elem, "OrderNumber"
      if import_country.iso_code == 'US'
        inv_line.mid = first_text elem, "OrganizationAddressCollection/OrganizationAddress[AddressType='Manufacturer']/RegistrationNumberCollection/RegistrationNumber[Type/Code='MID']/Value"
      end
      inv_line.part_number = et elem, "PartNo"
      inv_line.quantity = parse_decimal(et elem, "InvoiceQuantity")
      inv_line.unit_of_measure = first_text elem, "InvoiceQuantityUnit/Code"
      inv_line.value = parse_decimal(et elem, "LinePrice")
      inv_line.country_origin_code = get_invoice_line_country_origin_code elem, import_country.iso_code
      inv_line.country_export_code = get_invoice_line_country_export_code elem, import_country.iso_code, elem_invoice
      inv_line.related_parties = parse_boolean(first_text elem_invoice, "AddInfoCollection/AddInfo[Key='TransactionsRelated']/Value")
      inv_line.vendor_name = first_text elem, "OrganizationAddressCollection/OrganizationAddress[AddressType='Manufacturer']/CompanyName"
      inv_line.volume = parse_decimal(et elem, "Volume")
      inv_line.contract_amount = parse_decimal(first_text elem, "CustomizedFieldCollection/CustomizedField[Key='MMC']/Value")
      inv_line.department = first_text elem, "CustomizedFieldCollection/CustomizedField[Key='Department Number']/Value"
      inv_line.non_dutiable_amount = get_non_dutiable_amount elem
      inv_line.add_to_make_amount = get_add_to_make_amount elem
      inv_line.other_amount = get_other_amount elem
      inv_line.miscellaneous_discount = get_miscellaneous_discount elem
      inv_line.freight_amount = get_freight_amount elem
      inv_line.visa_number = first_text elem, "AddInfoCollection/AddInfo[Key='VisaNo']/Value"
      inv_line.visa_quantity = parse_decimal(first_text elem, "AddInfoCollection/AddInfo[Key='VisaQty']/Value")
      inv_line.visa_uom = first_text elem, "AddInfoCollection/AddInfo[Key='VisaUQ']/Value"
      inv_line.customs_line_number = et(elem, "EntryLineNumber").try(:to_i)
      if foreign_currency? first_text(elem_invoice, "InvoiceCurrency/Code"), import_country.iso_code
        line_value = parse_decimal(et elem, "LinePrice")
        inv_line.value = line_value
        inv_line.value_foreign = convert_foreign_invoice_value parse_decimal(et(elem_invoice, "AgreedExchangeRate"), decimal_places:6), line_value
      end
      inv_line.currency = first_text elem_invoice, "InvoiceCurrency/Code"
      inv_line.value_appraisal_method = parse_boolean(first_text elem, "AddInfoCollection/AddInfo[Key='FirstSale']/Value") ? "F" : nil
      inv_line.first_sale = parse_boolean(first_text elem, "AddInfoCollection/AddInfo[Key='FirstSale']/Value")
      inv_line.unit_price = parse_decimal(first_text elem, "UnitPrice")
      inv_line.agriculture_license_number = first_text elem, "CustomsReferenceCollection/CustomsReference[Type/Code='LNP' and SubType/Code='14']/Reference"
      inv_line.mpf = parse_decimal(first_text elem, "CustomsReferenceCollection/CustomsReference[SubType/Code='499']/Reference")
      inv_line.prorated_mpf = parse_decimal(first_text elem, "AddInfoCollection/AddInfo[Key='PayableMPF']/Value")
      inv_line.hmf = parse_decimal(first_text elem, "CustomsReferenceCollection/CustomsReference[SubType/Code='501']/Reference")
      inv_line.cotton_fee = parse_decimal(first_text elem, "CustomsReferenceCollection/CustomsReference[SubType/Code='056']/Reference")
      inv_line.other_fees = total_value elem, "CustomsReferenceCollection/CustomsReference[SubType/Code!='056' and SubType/Code!='499' and SubType/Code!='501' and Type/Code='FEE']/Reference"
      inv_line.add_case_number = first_text elem, "AddInfoCollection/AddInfo[Key='ADDCaseNo']/Value"
      inv_line.add_bond = parse_boolean(first_text elem, "AddInfoCollection/AddInfo[Key='IsBondedADD']/Value")
      inv_line.add_case_value = get_add_case_value elem, import_country.iso_code
      inv_line.add_duty_amount = get_add_duty_amount elem, import_country.iso_code
      inv_line.cvd_case_number = first_text elem, "AddInfoCollection/AddInfo[Key='CVDCaseNo']/Value"
      inv_line.cvd_bond = parse_boolean(first_text elem, "AddInfoCollection/AddInfo[Key='IsBondedCVD']/Value")
      inv_line.cvd_case_value = get_cvd_case_value elem, import_country.iso_code
      inv_line.cvd_duty_amount = get_cvd_duty_amount elem, import_country.iso_code
      if import_country.iso_code == 'CA'
        inv_line.state_export_code = first_text elem_invoice, "AddInfoCollection/AddInfo[Key='USStateOfExport']/Value"
        inv_line.state_origin_code = first_text elem, "StateOfOrigin/Code"
        inv_line.customer_reference = et elem, "OrderNumber"
        inv_line.adjustments_amount = total_value elem, "CommercialChargeCollection/CommercialCharge[ChargeType/Code='ADD' and IsDutiable='true']/Amount"
      end
    end

    def get_invoice_line_country_origin_code elem, import_country_iso
      v = nil
      if import_country_iso == 'US'
        v = first_text elem, "AddInfoCollection/AddInfo[Key='UC_NKCountryOfOrigin']/Value"
      elsif import_country_iso == 'CA'
        v = first_text elem, "CountryOfOrigin/Code"
      end
      v
    end

    def get_invoice_line_country_export_code elem, import_country_iso, elem_invoice
      v = nil
      if import_country_iso == 'US'
        v = first_text elem, "AddInfoCollection/AddInfo[Key='UC_NKCountryOfExport']/Value"
      elsif import_country_iso == 'CA'
        v = first_text elem_invoice, "AddInfoCollection/AddInfo[Key='RN_NKExport']/Value"
      end
      v
    end

    def get_non_dutiable_amount elem
      total_value elem, "CommercialChargeCollection/CommercialCharge[IsDutiable='false' and IsNotIncludedInInvoice='false']/Amount"
    end

    def get_add_to_make_amount elem
      total_value elem, "CommercialChargeCollection/CommercialCharge[IsDutiable='true']/Amount"
    end

    def get_other_amount elem
      total_value elem, "CommercialChargeCollection/CommercialCharge[ChargeType/Code='OTH']/Amount"
    end

    def get_miscellaneous_discount elem
      total_value elem, "CommercialChargeCollection/CommercialCharge[ChargeType/Code='DIS']/Amount"
    end

    def get_freight_amount elem
      # Per the map, unlike the others in the same category, this is NOT a total field.  We grab the first
      # 'OFT' charge.
      parse_decimal(first_text elem, "CommercialChargeCollection/CommercialCharge[ChargeType/Code='OFT']/Amount")
    end

    def get_add_case_value elem, import_country_iso
      v = nil
      if import_country_iso == 'US'
        v = parse_decimal(first_text elem, "AddInfoCollection/AddInfo[Key='ADDDepositValue']/Value")
      elsif import_country_iso == 'CA'
        v = parse_decimal(first_text elem, "AddInfoGroupCollection/AddInfoGroup[Type/Code='CDT']/AddInfoCollection[AddInfo/Key='TaxType' and AddInfo/Value='ADD']/AddInfo[Key='ValueForCalculation']/Value")
      end
      v
    end

    def get_add_duty_amount elem, import_country_iso
      v = nil
      if import_country_iso == 'US'
        v = parse_decimal(first_text elem, "AddInfoCollection/AddInfo[Key='ADDuty']/Value")
      elsif import_country_iso == 'CA'
        v = parse_decimal(first_text elem, "AddInfoGroupCollection/AddInfoGroup[Type/Code='CDT']/AddInfoCollection[AddInfo/Key='TaxType' and AddInfo/Value='ADD']/AddInfo[Key='Amount']/Value")
      end
      v
    end

    def get_cvd_case_value elem, import_country_iso
      v = nil
      if import_country_iso == 'US'
        v = parse_decimal(first_text elem, "AddInfoCollection/AddInfo[Key='CVDDepositValue']/Value")
      elsif import_country_iso == 'CA'
        v = parse_decimal(first_text elem, "AddInfoGroupCollection/AddInfoGroup[Type/Code='CDT']/AddInfoCollection[AddInfo/Key='TaxType' and AddInfo/Value='CVD']/AddInfo[Key='ValueForCalculation']/Value")
      end
      v
    end

    def get_cvd_duty_amount elem, import_country_iso
      v = nil
      if import_country_iso == 'US'
        v = parse_decimal(first_text elem, "AddInfoCollection/AddInfo[Key='CVDuty']/Value")
      elsif import_country_iso == 'CA'
        v = parse_decimal(first_text elem, "AddInfoGroupCollection/AddInfoGroup[Type/Code='CDT']/AddInfoCollection[AddInfo/Key='TaxType' and AddInfo/Value='CVD']/AddInfo[Key='Amount']/Value")
      end
      v
    end

    def update_parent_line_amounts inv_line, elem_child_line
      # None of these values can be nil due to the methods used to parse them.  At worst, they'll be zero.
      inv_line.non_dutiable_amount += get_non_dutiable_amount elem_child_line
      inv_line.add_to_make_amount += get_add_to_make_amount elem_child_line
      inv_line.other_amount += get_other_amount elem_child_line
      inv_line.miscellaneous_discount += get_miscellaneous_discount elem_child_line
      inv_line.freight_amount += get_freight_amount elem_child_line
    end

    def add_commercial_invoice_tariffs inv_line, elem_line, doc, import_country_iso, entry_effective_date, condensed_line
      entry_line_number = et elem_line, "EntryLineNumber"
      # Primary tariff number.  If we're dealing with a condensed invoice line, this is actually a provisional
      # tariff number, sent in the primary slot.  It should be handled as provisional.
      hts_code = et elem_line, "HarmonisedCode"
      if hts_code.present?
        tar = inv_line.commercial_invoice_tariffs.build(hts_code:hts_code)
        populate_commercial_invoice_tariff tar, inv_line, elem_line, import_country_iso, find_matching_entry_line(doc, entry_line_number, hts_code), true, condensed_line

        # The full gamut of duty rates are set for the US only, and only for the primary tariff number.
        # Base duty rate can still be calculated for US non-primary tariffs.
        if import_country_iso == 'US'
          if !condensed_line
            calculate_duty_rates tar, inv_line, entry_effective_date, BigDecimal.new(tar.entered_value_7501)
          else
            calculate_primary_duty_rate tar, BigDecimal.new(tar.entered_value_7501)
          end
        end
      end

      # Provisional tariff numbers.
      prov_hts_codes = unique_values elem_line, "AddInfoCollection/AddInfo[Key='SupTariff']/Value"
      prov_hts_codes.each do |prov_hts_code|
        tar = inv_line.commercial_invoice_tariffs.build(hts_code:prov_hts_code)
        populate_commercial_invoice_tariff tar, inv_line, elem_line, import_country_iso, find_matching_entry_line(doc, entry_line_number, prov_hts_code), false, condensed_line
        if import_country_iso == 'US'
          customs_value = tar.entered_value_7501
          if customs_value.nil? || customs_value.zero?
            customs_value = parse_integer(et elem_line, "CustomsValue")
          end
          calculate_primary_duty_rate tar, BigDecimal.new(customs_value) unless customs_value.nil?
        end
      end
    end

    # Finds the entry line connected to an invoice tariff within the XML structure.
    def find_matching_entry_line doc, entry_line_number, hts_code
      xpath(doc, "UniversalShipment/Shipment/EntryHeaderCollection/EntryHeader/EntryLineCollection/EntryLine[LineNumber='#{entry_line_number}' and HarmonisedCode='#{hts_code}']").first
    end

    def populate_commercial_invoice_tariff tar, inv_line, elem_invoice_line, import_country_iso, elem_entry_line, primary_tariff, condensed_line
      tar.duty_advalorem = get_advalorem_duty elem_invoice_line, import_country_iso, elem_entry_line
      tar.duty_amount = get_duty elem_invoice_line, import_country_iso, primary_tariff
      # Some of these fields are not set for the supplemental tariffs.  It's possible more fields currently being
      # set might be better off left blank, since the only thing we've got to plop into them is dupe of the
      # primary tariff content.
      if primary_tariff && !condensed_line
        # Don't let this value be negative.  It can happen sometimes due to an apparent rounding quirk in Cargowise.
        tar.duty_specific = [tar.duty_amount - tar.duty_advalorem, BigDecimal.new(0)].max
        tar.duty_additional = get_duty_additional elem_invoice_line
        tar.entered_value = parse_decimal(et elem_invoice_line, "CustomsValue")
        tar.entered_value_7501 = parse_integer(et elem_invoice_line, "CustomsValue")
        tar.classification_qty_1 = parse_decimal(et elem_invoice_line, "CustomsQuantity")
        tar.classification_uom_1 = first_text elem_invoice_line, "CustomsQuantityUnit/Code"
      else
        tar.entered_value = BigDecimal("0")
        tar.entered_value_7501 = 0
      end
      inv_line.entered_value_7501 = inv_line.entered_value_7501.to_i + tar.entered_value_7501
      if primary_tariff && !condensed_line
        tar.spi_primary = get_spi_primary elem_invoice_line, import_country_iso
        tar.spi_secondary = first_text elem_invoice_line, "AddInfoCollection/AddInfo[Key='SetInd']/Value"
        tar.classification_qty_2 = get_classification_qty_2 elem_invoice_line, import_country_iso
        tar.classification_uom_2 = get_classification_uom_2 elem_invoice_line, import_country_iso
        tar.classification_qty_3 = get_classification_qty_3 elem_invoice_line, import_country_iso
        tar.classification_uom_3 = get_classification_uom_3 elem_invoice_line, import_country_iso
        tar.quota_category = first_text elem_invoice_line, "AddInfoCollection/AddInfo[Key='TextileCategoryNo']/Value"
        if import_country_iso == 'CA'
          tar.tariff_provision = first_text elem_invoice_line, "AddInfoCollection/AddInfo[Key='99TariffCode']/Value"
          tar.value_for_duty_code = first_text elem_invoice_line, "AddInfoCollection/AddInfo[Key='ValueForDutyCode']/Value"
          tar.special_authority = first_text elem_invoice_line, "AddInfoCollection/AddInfo[Key='AuthorityNumber']/Value"
          tar.gst_rate_code = first_text elem_invoice_line, "AddInfoGroupCollection/AddInfoGroup/AddInfoCollection[AddInfo/Key='RateType' and AddInfo/Value='V'][AddInfo/Key='TaxType' and AddInfo/Value='GST']/AddInfo[Key='Rate']/Value"
          tar.gst_amount = parse_decimal(first_text elem_invoice_line, "AddInfoGroupCollection/AddInfoGroup/AddInfoCollection[AddInfo/Key='RateType' and AddInfo/Value='V'][AddInfo/Key='TaxType' and AddInfo/Value='GST']/AddInfo[Key='Amount']/Value")
          tar.sima_amount = parse_decimal(first_text elem_invoice_line, "AddInfoGroupCollection/AddInfoGroup/AddInfoCollection[AddInfo/Key='RateType' and AddInfo/Value='V'][AddInfo/Key='TaxType' and (AddInfo/Value='SUR' or AddInfo/Value='ADD' or AddInfo/Value='CVD')]/AddInfo[Key='Amount']/Value")
          tar.sima_code = first_text elem_invoice_line, "AddInfoGroupCollection/AddInfoGroup/AddInfoCollection[AddInfo/Key='RateType' and AddInfo/Value='V'][AddInfo/Key='TaxType' and (AddInfo/Value='SUR' or AddInfo/Value='ADD' or AddInfo/Value='CVD')]/AddInfo[Key='Rate']/Value"
          tar.duty_rate = elem_entry_line ? (parse_decimal(et(elem_entry_line, "DutyRatePercent")) / BigDecimal.new(100)).round(3, BigDecimal::ROUND_HALF_UP) : BigDecimal.new(0)
        end
        # Gross weight is an integer field for some reason.
        tar.gross_weight = parse_integer(et elem_invoice_line, "Weight")
      end
      tar.tariff_description = et elem_invoice_line, "Description"
    end

    def get_advalorem_duty elem_invoice_line, import_country_iso, elem_entry_line
      v = BigDecimal.new(0)
      if import_country_iso == 'US' && elem_entry_line
        duty_rate_percent = parse_decimal(et elem_entry_line, "DutyRatePercent", decimal_places:5)
        if duty_rate_percent > 0
          customs_value = parse_decimal(et elem_invoice_line, "CustomsValue", decimal_places:5)
          v = ((duty_rate_percent * customs_value) / BigDecimal("100")).round(2, BigDecimal::ROUND_HALF_UP)
        end
      elsif import_country_iso == 'CA'
        v = parse_decimal(first_text elem_invoice_line, "AddInfoGroupCollection/AddInfoGroup[Type/Code='CDT']/AddInfoCollection[AddInfo/Key='RateType' and AddInfo/Value='V'][AddInfo/Key='TaxType' and AddInfo/Value='DTY']/AddInfo[Key='Amount']/Value")
      end
      v
    end

    def get_duty elem_invoice_line, import_country_iso, primary_tariff
      v = BigDecimal.new(0)
      if import_country_iso == 'US'
        if primary_tariff
          v = parse_decimal(first_text elem_invoice_line, "AddInfoCollection/AddInfo[Key='Duty']/Value")
        else
          v = parse_decimal(first_text elem_invoice_line, "AddInfoCollection/AddInfo[Key='SupDuty']/Value")
        end
      elsif import_country_iso == 'CA'
        v = total_value elem_invoice_line, "AddInfoGroupCollection/AddInfoGroup/AddInfoCollection[AddInfo/Key='TaxType' and AddInfo/Value='DTY']/AddInfo[Key='Amount']/Value"
      end
      v
    end

    def get_duty_additional elem_invoice_line
      v = BigDecimal.new(0)
      # For unknown reasons, Nokogiri cannot handle this xpath properly:
      # "AddInfoGroupCollection/AddInfoGroup[Type/Code='CDT']/AddInfoCollection[AddInfo/Key='TaxType' and AddInfo/Value!='ADD' and AddInfo/Value!='CVD']/AddInfo[Key='Amount']/Value"
      # It does not exclude ADD and CVD as it should.  So, to work around that, we're no longer trying to handle this
      # with one xpath.
      xpath(elem_invoice_line, "AddInfoGroupCollection/AddInfoGroup[Type/Code='CDT']") do |elem_cdt|
        tax_type = first_text elem_cdt, "AddInfoCollection/AddInfo[Key='TaxType']/Value"
        if !['ADD', 'CVD'].include?(tax_type.to_s.upcase)
          amount = first_text elem_cdt, "AddInfoCollection/AddInfo[Key='Amount']/Value"
          if amount.present?
            v = parse_decimal amount
            break
          end
        end
      end
      v
    end

    def get_spi_primary elem_invoice_line, import_country_iso
      v = nil
      if import_country_iso == 'US'
        v = first_text elem_invoice_line, "AddInfoCollection/AddInfo[Key='SPI']/Value"
      elsif import_country_iso == 'CA'
        v = first_text elem_invoice_line, "AddInfoCollection/AddInfo[Key='TreatmentCode']/Value"
      end
      v
    end

    def get_classification_qty_2 elem_invoice_line, import_country_iso
      v = BigDecimal.new(0)
      if import_country_iso == 'US'
        v = parse_decimal(first_text elem_invoice_line, "AddInfoCollection/AddInfo[Key='SecondQty']/Value")
      elsif import_country_iso == 'CA'
        v = parse_decimal(first_text elem_invoice_line, "AddInfoCollection/AddInfo[Key='Qty2']/Value")
      end
      v
    end

    def get_classification_uom_2 elem_invoice_line, import_country_iso
      v = nil
      if import_country_iso == 'US'
        v = first_text elem_invoice_line, "AddInfoCollection/AddInfo[Key='SecondUQ']/Value"
      elsif import_country_iso == 'CA'
        v = first_text elem_invoice_line, "AddInfoCollection/AddInfo[Key='Qty2UM']/Value"
      end
      v
    end

    def get_classification_qty_3 elem_invoice_line, import_country_iso
      v = BigDecimal.new(0)
      if import_country_iso == 'US'
        v = parse_decimal(first_text elem_invoice_line, "AddInfoCollection/AddInfo[Key='ThirdQty']/Value")
      elsif import_country_iso == 'CA'
        v = parse_decimal(first_text elem_invoice_line, "AddInfoCollection/AddInfo[Key='Qty3']/Value")
      end
      v
    end

    def get_classification_uom_3 elem_invoice_line, import_country_iso
      v = nil
      if import_country_iso == 'US'
        v = first_text elem_invoice_line, "AddInfoCollection/AddInfo[Key='ThirdUQ']/Value"
      elsif import_country_iso == 'CA'
        v = first_text elem_invoice_line, "AddInfoCollection/AddInfo[Key='Qty3UM']/Value"
      end
      v
    end

    def get_total_non_dutiable_amount entry
      total = BigDecimal.new(0)
      entry.commercial_invoices.each { |i| total += i.non_dutiable_amount }
      total
    end

    def get_total_other_fees entry
      total = BigDecimal.new(0)
      # Entry has not yet been saved when this method is called, so we can't access lines directly from it.
      entry.commercial_invoices.each { |ci| ci.commercial_invoice_lines.each { |i| total += i.other_fees if i.other_fees.present? }}
      total
    end

    def get_us_total_fees entry
      total = BigDecimal.new(0)
      # Entry has not yet been saved when this method is called, so we can't access lines directly from it.
      entry.commercial_invoices.each { |ci| ci.commercial_invoice_lines.each { |i| total += [i.cotton_fee, i.other_fees, i.prorated_mpf, i.hmf].compact.sum }}
      total
    end

    def get_last_billed_date entry
      entry.broker_invoices.maximum(:invoice_date)
    end

    def get_po_numbers entry
      po_numbers = []
      # Entry has not yet been saved when this method is called, so we can't access lines directly from it.
      entry.commercial_invoices.each { |ci| ci.commercial_invoice_lines.each { |cil| po_numbers << cil.po_number unless cil.po_number.blank? } }
      po_numbers.uniq
    end

    def calculate_duty_rates invoice_tariff, invoice_line, effective_date, customs_value
      super

      # Depending on calculated duty rate presence, we may have to make some adjustments to duty values.
      if (invoice_tariff.specific_rate.nil? || invoice_tariff.specific_rate == 0)
        invoice_tariff.duty_specific = BigDecimal.new(0)
      end

      if (invoice_tariff.specific_rate.nil? || invoice_tariff.specific_rate == 0) && (invoice_tariff.additional_rate.nil? || invoice_tariff.additional_rate == 0)
        invoice_tariff.duty_advalorem = invoice_tariff.duty_amount
      end
    end

    def populate_container cont, elem
      cont.container_number = et elem, "ContainerNumber"
      cont.container_size = first_text elem, "ContainerType/Code"
      # Weight is an integer field for some reason.
      cont.weight = parse_integer(et elem, "GrossWeight")
      cont.seal_number = et elem, "Seal"
      cont.fcl_lcl = first_text elem, "FCL_LCL_AIR/Code"
      cont.size_description = first_text elem, "ContainerType/Description"
    end

    def add_entry_comment entry, note, public_comment
      username = public_comment ? "Broker" : "Private Broker"
      # Look for this comment within the entry, adding it only if it doesn't already exist.  There's no better
      # way to do this check than by comment content, unfortunately.
      if entry.entry_comments.find { |comm| comm.username == username && comm.body == note }.nil?
        comment = entry.entry_comments.build
        comment.body = note
        comment.username = username
        comment.public_comment = public_comment
        # There is no obvious date value in UniversalShipment's Notes segments.
        comment.generated_at = Time.zone.now
      end
      nil
    end

end; end; end; end
