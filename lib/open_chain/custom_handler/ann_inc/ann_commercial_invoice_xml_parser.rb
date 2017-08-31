require 'open_chain/integration_client_parser'
require 'open_chain/api/product_api_client'
require 'open_chain/custom_handler/vandegrift/kewill_commercial_invoice_generator'
require 'open_chain/custom_handler/vandegrift/kewill_shipment_xml_support'

module OpenChain; module CustomHandler; module AnnInc; class AnnCommercialInvoiceXmlParser
  extend OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::Vandegrift::KewillShipmentXmlSupport

  def self.integration_folder
    "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_ann_invoice"
  end

  def self.parse data, opts = {}
    self.new.parse(REXML::Document.new data)
  end

  def parse xml
    REXML::XPath.each(xml, "/UniversalInterchange/Body/UniversalShipment/Shipment/CommercialInfo/CommercialInvoiceCollection/CommercialInvoice").each do |invoice|
      process_invoice(invoice)
    end
  end

  def process_invoice invoice_xml
    invoice = process_invoice_header(invoice_xml)
    REXML::XPath.each(invoice_xml, "CommercialInvoiceLineCollection/CommercialInvoiceLine") do |line_xml|
      invoice.invoice_lines << process_invoice_line(invoice_xml, line_xml)
    end

    # We need to wrap the invoice in an entry struct before sending
    entry = CiLoadEntry.new
    entry.invoices = [invoice]
    entry.customer = ann_importer.alliance_customer_number

    send_invoice entry
  end

  def process_invoice_header invoice_xml
    inv = CiLoadInvoice.new

    inv.invoice_number = invoice_xml.text("InvoiceNumber")
    inv.currency = invoice_xml.text "InvoiceCurrency/Code"
    inv.exchange_rate = dec(invoice_xml.text "AgreedExchangeRate")
    inv.invoice_date = date(invoice_xml.text "InvoiceDate")
    inv.invoice_lines = []

    inv
  end

  def process_invoice_line invoice_xml, line_xml
    line = CiLoadInvoiceLine.new
    line.po_number = line_xml.text "OrderNumber"
    line.part_number = line_xml.text "PartNo"
    line.country_of_origin = REXML::XPath.first(invoice_xml, "OrganizationAddressCollection/OrganizationAddress[AddressType = 'Manufacturer']/Country/Code").try(:text)
    line.quantity_2 = net_weight(line_xml)
    line.pieces = dec(line_xml.text "InvoiceQuantity")
    line.hts = us_hts(line.part_number)
    
    # Geodis doesn't include all the discounts / etc in the 810 XML, so we don't really
    # have any actual way to know what the actual entered value should be on the entry, 
    # therefore operations will have to manually do all that.  All we'll do here is 
    # pass through the invoice line amount
    line.foreign_value = dec(line_xml.text "LinePrice")

    line.quantity_1 = dec(line_xml.text "CustomsQuantity")
    line.department = customized_field_value(line_xml, "Department")

    line.buyer_customer_number = ann_importer.alliance_customer_number
    line.cartons = dec(customized_field_value(line_xml, "Cartons"))

    # Always add back in the sum of the discounts to the foreign value
    discounts = discounts_total(line_xml)
    line.foreign_value += discounts

    # If middleman is more than the discounts, send a First Sale of LinePrice + Discounts + Middleman Charge
    middleman = middleman_charge(line_xml)
    if middleman > discounts
      line.non_dutiable_amount = (middleman * -1)
      line.first_sale = (line.foreign_value + middleman)
    else
      # This is done w/ a negative value because the CI Load handler looks for a negative value in the MMV/NDC field 
      # as an indicator of whether to use the value there for non_dutiable_amount or not.
      line.non_dutiable_amount = (discounts * -1) if discounts > 0
    end

    if line.foreign_value && line.pieces
      line.unit_price = (line.foreign_value / line.pieces).round(2, :half_up)
    end

    line
  end

  def send_invoice invoice_data
    kewill_generator.generate_xls_to_google_drive "Ann CI Load/#{Attachment.get_sanitized_filename(invoice_data.invoices.first.invoice_number)}.xls", [invoice_data]
  end

  def kewill_generator
    OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator.new
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
    weight = BigDecimal(line_xml.text("NetWeight") || "0")
    return nil unless weight.nonzero?

    uom = line_xml.text("NetWeightUnit/Code")
    if uom.to_s.upcase.starts_with? "LB"
      # Convert to KG
      weight = (weight * BigDecimal("0.453592")).round(2, :half_up)
    end

    weight
  end

  def us_hts part_number
    product = api_client.find_by_uid part_number, ["class_cntry_iso", "hts_hts_1"]
    if product["product"].nil?
      # It's possible the part_number we have is actually a related style, so we have to do a search for that
      product = related_style_search part_number
    else
      product = product["product"]
    end

    hts = nil
    if product
      classification = product["classifications"].find {|c| c["class_cntry_iso"].to_s.upcase == "US" }
      if classification
        hts = classification["tariff_records"].first.try(:[], 'hts_hts_1')
      end
    end

    hts
  end

  def related_style_search part_number
    # This is kinda hairy, in that, the model field uid here is hardcoded, but it's never going to change
    # in Ann's system.
    criterion = SearchCriterion.new operator: "co", value: part_number
    # This is a hack to avoid having the custom definition criterion load (since the cf value we're using is not in the current system)
    criterion[:model_field_uid] = "*cf_35"

    search_result = api_client.search fields: ["class_cntry_iso", "hts_hts_1"], search_criterions: [criterion], per_page: 1
    search_result["results"].try :first
  end

  def calculate_discount invoice_line_xml
    discount_sum = discounts_total(invoice_line_xml)
    middleman = middleman_charge(invoice_line_xml)

    discount_sum > middleman ? discount_sum : middleman
  end

  def discounts_total invoice_line_xml
    air_sea = BigDecimal(customized_field_value(invoice_line_xml, "Air/Sea Discount").to_s)
    early_payment = BigDecimal(customized_field_value(invoice_line_xml, "Early Payment Discount").to_s)
    trade_discount = BigDecimal(customized_field_value(invoice_line_xml, "Trade Discount").to_s)

    [air_sea, early_payment, trade_discount].sum
  end

  def middleman_charge invoice_line_xml
    BigDecimal(customized_field_value(invoice_line_xml, "Middleman Charges").to_s)
  end

  def ann_importer
    @ann ||= Company.importers.where(system_code: "ATAYLOR").first
    raise "No Ann Taylor importer with system code 'ATAYLOR'." unless @ann

    @ann
  end

  def api_client
    OpenChain::Api::ProductApiClient.new 'ann'
  end

end; end; end; end