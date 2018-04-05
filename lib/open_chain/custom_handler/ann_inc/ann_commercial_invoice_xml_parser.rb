require 'open_chain/integration_client_parser'

module OpenChain; module CustomHandler; module AnnInc; class AnnCommercialInvoiceXmlParser
  extend OpenChain::IntegrationClientParser

  def self.integration_folder
    ["www-vfitrack-net/_ann_invoice", "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_ann_invoice"]
  end

  def self.parse data, opts = {}
    self.new.parse(REXML::Document.new data)
  end

  def ann_importer
    @ann ||= Company.importers.where(system_code: "ATAYLOR").first
    raise "No Ann Taylor importer with system code 'ATAYLOR'." unless @ann

    @ann
  end

  def parse xml
    invoice_path = "/UniversalInterchange/Body/UniversalShipment/Shipment/CommercialInfo/CommercialInvoiceCollection/CommercialInvoice"
    REXML::XPath.each(xml, invoice_path).each { |invoice| process_invoice(invoice) }
  end

  def process_invoice invoice_xml
    check_importer invoice_xml
    inv_number = invoice_xml.text("InvoiceNumber").gsub(/\W/,"")
    inv = nil
    Lock.acquire("Invoice-ATAYLOR-#{inv_number}") { inv = Invoice.where(importer_id: ann_importer.id, invoice_number: inv_number).first_or_create! }
    Lock.with_lock_retry(inv) do
      assign_invoice_header inv, invoice_xml
      inv_line_path = "CommercialInvoiceLineCollection/CommercialInvoiceLine"
      inv.invoice_lines.destroy_all
      REXML::XPath.each(invoice_xml, inv_line_path) { |line_xml| process_invoice_line(inv, line_xml) }
      inv.save!
    end
  end

  def assign_invoice_header inv, invoice_xml
    assign_header_fields inv, invoice_xml
    assign_vendor inv, invoice_xml
    assign_factory inv, invoice_xml
  end

  def check_importer invoice_xml
    importer_code = invoice_xml.text "OrganizationAddressCollection/OrganizationAddress[AddressType='Importer']/OrganizationCode"
    raise "Unexpected importer code: #{importer_code}" unless importer_code == "ANNTAYNYC"
  end

  def assign_header_fields inv, invoice_xml
    inv.importer = ann_importer
    inv.exchange_rate = dec(invoice_xml.text "AgreedExchangeRate")
    inv.gross_weight = dec(invoice_xml.text "Weight")
    inv.gross_weight_uom = "KG"
    inv.invoice_date = date(invoice_xml.text "InvoiceDate")
    inv.currency = invoice_xml.text "InvoiceCurrency/Code"
    inv.invoice_total_foreign = dec(invoice_xml.text "InvoiceAmount")
    inv.invoice_total_domestic = inv.exchange_rate.zero? ? 0 : inv.invoice_total_foreign / inv.exchange_rate

    nil
  end

  def assign_vendor inv, invoice_xml
    vendor_xml = REXML::XPath.first invoice_xml, "Supplier"
    new_vendor = Company.new(vendor: true, name: vendor_xml.text("CompanyName"))
    addr = create_address new_vendor, vendor_xml
    uid = "#{ann_importer.system_code}-#{Address.make_hash_key addr}"
    old_vendor = Company.where(system_code: uid).includes(:addresses).first
    if old_vendor
      # each address defines a new vendor, so one address can be assumed
      inv.country_origin = old_vendor.addresses.first.country 
      inv.vendor = old_vendor
    else
      new_vendor.update_attributes!(system_code: uid, addresses: [addr])
      inv.country_origin = addr.country
      inv.vendor = new_vendor
    end
    
    nil
  end

  def assign_factory inv, invoice_xml
    factory_xml = REXML::XPath.first invoice_xml, "OrganizationAddressCollection/OrganizationAddress[AddressType='Manufacturer']"
    new_factory = Company.new(factory: true, name: factory_xml.text("CompanyName") )
    addr = create_address new_factory, factory_xml 
    uid = "#{ann_importer.system_code}-#{Address.make_hash_key addr}"
    old_factory = Company.where(system_code: uid).first
    if old_factory
      inv.factory = old_factory
    else
      new_factory.update_attributes! system_code: uid, addresses: [addr]
      inv.factory = new_factory
    end

    nil
  end

  def create_address co, xml
    addr = Address.new(company: co)
    addr.name = co.name
    addr.line_1 = xml.text "Address1"
    addr.line_2 = xml.text "Address2"
    addr.city = xml.text "City"
    addr.country = Country.where(iso_code: xml.text("Country/Code")).first
    addr
  end

  def process_invoice_line invoice, line_xml
    line = invoice.invoice_lines.build
    
    line.air_sea_discount = dec(customized_field_value line_xml, 'Air/Sea Discount')
    line.department =  customized_field_value(line_xml, 'Department')
    line.early_pay_discount = dec(customized_field_value line_xml, 'Early Payment Discount')
    line.trade_discount = dec(customized_field_value line_xml, "Trade Discount")
    line.fish_wildlife = customized_field_value line_xml, 'Fish &amp; Wildlife' 
    line.line_number = line_xml.text "LineNo"
    line.middleman_charge = middleman_charge line_xml
    line.net_weight = line_xml.text("NetWeight")
    line.net_weight_uom = line_xml.text("NetWeightUnit/Code")
    line.part_description = line_xml.text "Description"
    line.part_number = line_xml.text "PartNo"
    line.po_number = line_xml.text "OrderNumber"
    line.pieces = dec(line_xml.text "InvoiceQuantity")
    line.quantity = dec(line_xml.text "CustomsQuantity")
    line.quantity_uom = line_xml.text "CustomsQuantityUnit/Code"
    line.value_foreign = dec(line_xml.text "CustomsValue")
    line.value_domestic = invoice.exchange_rate.to_f.zero? ? 0 : line.value_foreign / invoice.exchange_rate
    line.unit_price = (line.value_foreign / line.pieces).round(2, :half_up) if line.value_foreign && line.pieces

    line
  end

  def dec v
    v.nil? ? nil : BigDecimal(v)
  end

  def date v
    v.nil? ? nil : Time.zone.parse(v).to_date
  end

  def customized_field_value invoice_line_xml, key
    REXML::XPath.first(invoice_line_xml, "CustomizedFieldCollection/CustomizedField[Key = '#{key}']/Value").try(:text)
  end

  def net_weight line_xml
    weight = dec(line_xml.text("NetWeight"))
    return nil unless weight.nonzero?

    uom = line_xml.text("NetWeightUnit/Code")
    if uom.to_s.upcase.starts_with? "LB"
      # Convert to KG
      weight = (weight * BigDecimal("0.453592")).round(2, :half_up)
    end

    weight
  end

  def calculate_discount invoice_line_xml
    discount_sum = discounts_total(invoice_line_xml)
    middleman = middleman_charge(invoice_line_xml)

    discount_sum > middleman ? discount_sum : middleman
  end

  def discounts_total invoice_line_xml
    air_sea = dec(customized_field_value(invoice_line_xml, "Air/Sea Discount"))
    early_payment = dec(customized_field_value(invoice_line_xml, "Early Payment Discount"))
    trade_discount = dec(customized_field_value(invoice_line_xml, "Trade Discount"))

    [air_sea, early_payment, trade_discount].sum
  end

  def middleman_charge invoice_line_xml
    dec(customized_field_value(invoice_line_xml, "Middleman Charges"))
  end

end; end; end; end
