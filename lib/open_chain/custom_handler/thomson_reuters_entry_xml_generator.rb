require 'action_view/helpers/number_helper'
require 'open_chain/xml_builder'

# Abstract class to serve as a base for country/company-specific implementations.  The following methods must be
# implemented:
#   root_name - string value that is to be the name of the root element
# There are also several other methods that can be overridden/extended as needed.
module OpenChain; module CustomHandler; class ThomsonReutersEntryXmlGenerator
  include OpenChain::XmlBuilder
  include ActionView::Helpers::NumberHelper

  def generate_xml entry
    preload_entry entry
    doc, elem_root = build_xml_document root_name
    add_namespace_content elem_root

    elem_dec = make_declaration_element elem_root, entry
    entry.commercial_invoices.each do |inv|
      inv.commercial_invoice_lines.each do |inv_line|
        inv_line.commercial_invoice_tariffs.each_with_index do |tar, tar_idx|
          make_declaration_line_element elem_dec, entry, inv, inv_line, tar, tar_idx
        end
      end
    end

    doc
  end

  def add_namespace_content elem_root
    # Does nothing by default.
  end

  def make_declaration_element elem_root, entry
    elem_dec = add_element(elem_root, "Declaration")
    add_element elem_dec, "EntryNum", entry.entry_number
    add_element elem_dec, "BrokerFileNum", entry.broker_reference
    add_element elem_dec, "BrokerID", entry.entry_filer
    add_element elem_dec, "BrokerName", "Vandegrift Inc"
    add_element elem_dec, "EntryType", entry.entry_type
    add_element elem_dec, "PortOfEntry", entry.entry_port_code
    add_element elem_dec, "UltimateConsignee", entry.ult_consignee_name
    add_element elem_dec, "ReleaseDate", format_date(entry.release_date)
    add_element elem_dec, "TotalEnteredValue", format_decimal(entry.entered_value)
    add_element elem_dec, "CurrencyCode", entry.commercial_invoices.first&.currency
    add_element elem_dec, "ModeOfTransport", entry.transport_mode_code.to_s
    add_element elem_dec, "PortOfLading", entry.lading_port_code
    add_element elem_dec, "TotalDuty", format_decimal(entry.total_duty)
    elem_dec
  end

  def format_date d
    d&.strftime('%Y-%m-%d %H:%M:%S')
  end

  def make_declaration_line_element elem_dec, entry, inv, inv_line, tar, _tariff_sequence_number
    elem_line = add_element(elem_dec, "DeclarationLine")
    add_element elem_line, "SupplierName", inv_line.vendor_name.presence || inv.vendor_name
    add_element elem_line, "InvoiceNum", inv.invoice_number
    add_element elem_line, "PurchaseOrderNum", inv_line.po_number
    # In the event there are multiple bills of lading, we're to include only the first.
    add_element elem_line, "MasterBillOfLading", first_val(inv.master_bills_of_lading.presence || entry.master_bills_of_lading)
    add_element elem_line, "HouseBillOfLading", first_val(inv.house_bills_of_lading.presence || entry.house_bills_of_lading)
    add_element elem_line, "ProductNum", inv_line.part_number
    add_element elem_line, "HsNum", tar.hts_code
    add_element elem_line, "GrossWeight", (tar.gross_weight.presence || inv.gross_weight).to_s
    add_element elem_line, "TxnQty", format_decimal(tar.classification_qty_1)
    add_element elem_line, "LineValue", inv_line.value.to_s
    add_element elem_line, "InvoiceCurrency", inv_line.currency.presence || inv.currency
    add_element elem_line, "InvoiceQty", format_decimal(inv_line.quantity)
    add_element elem_line, "InvoiceValue", format_decimal(inv_line.value_foreign)
    add_element elem_line, "TxnQtyUOM", tar.classification_uom_1
    add_element elem_line, "WeightUOM", "KG"
    elem_line
  end

  def first_val str
    str&.split("\n ")&.first
  end

  def format_boolean val
    val ? "Y" : "N"
  end

  # Looking for the original number from the database field with any pointless zeros removed.
  def format_decimal val
    number_with_precision(val, precision: 10, strip_insignificant_zeros: true)
  end

  private

    def preload_entry entry
      ActiveRecord::Associations::Preloader.new.preload(entry, [{commercial_invoices: {commercial_invoice_lines: :commercial_invoice_tariffs}}, :sync_records])
    end

end; end; end
