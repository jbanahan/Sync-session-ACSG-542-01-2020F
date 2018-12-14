require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/custom_handler/gt_nexus/generic_gtn_parser_support'

# This class is meant to be extended for customer specific Invoice loads in the GT Nexus 
# invoice xml format.
#
# By default, the parse handles finding / creating all invoices listed in the xml
# and provides simple overridable methods to use to extend the base information extracted from the xml
# for the Invoice, InvoiceLine and Company records it generates.
# 
# Additionally some configuration values can be set by a constructor.
#
# The bare minimum that must be done to extend this class is to implement the following methods:
# 
# - initialize - Your initialize method must call super and pass a configuration hash.  If you want to 
# stick with the defaults, pass a blank hash.  See initialize below to see the configuration options available.
# - importer_system_code
# - party_system_code
#
# Additional methods of interest provided for ease of adding customer specific values are:
# 
# - set_additional_invoice_information
# - set_additional_invoice_line_information
# - set_additional_party_information
#
#
module OpenChain; module CustomHandler; module GtNexus; class GenericGtnInvoiceXmlParser
  include OpenChain::CustomHandler::GtNexus::GenericGtnParserSupport
  include OpenChain::IntegrationClientParser
  
  # Used as an extension point for any extending class to add any customer
  # specific information to the invoice.
  def set_additional_invoice_information invoice, invoice_xml
    nil
  end

  # Used as an extension point for any extending class to add any customer
  # specific information to the invoice line.
  def set_additional_invoice_line_information invoice, invoice_line, item_xml
    nil
  end

  def set_additional_party_information company, party_xml, party_type
    # This is an extension point for adding customer specific data to a party.
    # For instance, adding the MID for a factory that is sent with customer specific identifiers
  end

  # Return the system code to utilize on the purchase orders.
  # It's possible that the same GT Nexus account may map to multiple of our importers,
  # ergo the need to pass the order xml.
  # This method is called once at the beginning of parsing the XML and never again.
  def importer_system_code order_xml
    inbound_file.error_and_raise("Your customer specific class extension must implement this method, returning the system code of the importer to utilize on the Invoices.")
  end

  # Return the system code to use for the party xml given.  
  # DO NOT do any prefixing (like w/ the importer system code), the caller will handle all of that
  # for you.  Just return the identifying information for the party using the provided XML party element.
  def party_system_code party_xml, party_type
    # I'm pretty sure in the vast majority of cases we should be using customer specific identifiers
    # inside the identification element...those appear to be 100% customer specific though and not 
    # generic, so we'll have to have this be overriden to determine which internal code in the party object should
    # be used in all cases.
    inbound_file.error_and_raise("This method must be overriden by an implementing class.")
  end

  def initialize configuration
    # In general, you'll want to set this to false on customer specific systems (ll, polo, etc)
    @prefix_identifiers_with_system_codes = configuration[:prefix_identifiers_with_system_codes].nil? ? true : configuration[:prefix_identifiers_with_system_codes]

    @error_if_missing_order_line = configuration[:error_if_missing_order_line].nil? ? false : configuration[:error_if_missing_order_line]
  end

  def prefix_identifiers_with_system_codes?
    @prefix_identifiers_with_system_codes
  end

  def error_if_missing_order_line?
    @error_if_missing_order_line
  end

  def self.parse data, opts = {}
    xml = REXML::Document.new(data)

    user = User.integration

    # I don't believe GTN actually exports multiple Invoices per XML document, they use the
    # same schema for uploading to them and downloading from them, so the functionality is 
    # there to send them mulitple Invoices, but as to getting them exported to us on event triggers,
    # I don't think we get more than one per XML document
    parser = self.new
    REXML::XPath.each(xml.root, "/Invoice/invoiceDetail") do |invoice|
      parser.process_invoice(invoice, user, opts[:bucket], opts[:key])
    end

  end

  def process_invoice xml, user, bucket, key
    set_importer_system_code(xml)
    parties = parse_parties(xml, user, key)
    i = nil
    find_or_create_invoice(xml, bucket, key) do |invoice|
      
      prep_existing_invoice_lines(invoice, xml)

      set_parties(invoice, parties)
      set_invoice_information(invoice, xml)
      parse_invoice_lines(invoice, xml)
      sort_invoice_lines(invoice)
      set_invoice_totals(invoice)

      invoice.save!
      invoice.create_snapshot user, nil, key

      i = invoice
    end

    i
  end

  def prep_existing_invoice_lines invoice, xml
    # It appears that GTN doesn't really have any sort of invoice line number in the XML 
    # The specs intimate that ItemSequenceNumber is the invoice line number, but it's not, its just a copy of the
    # order line number...that being the case...we're just going to destroy every line and rebuild the invoice every time.
    invoice.invoice_lines.destroy_all
  end

  def sort_invoice_lines invoice
    # In order for this sorting to work, there's some assumptions being made here..
    # 1) None of the invoice lines have been persisted yet.  
    #    - This should be fine because we're destroying and recreating the invoice lines
    # 2) invoice.invoice_lines.clear is simply clearing the internal object array proxy
    #   - This should be fine because none of the lines are persisted (see #1), thus
    #   rails is smart enough not to issue a db call when it doesn't need to.

    sorted_lines = do_invoice_line_sorting(invoice.invoice_lines.to_a)
    # If nil is returned, the lines are assumed to already be in the desired order, no action is necessary.
    if !sorted_lines.nil?
      invoice.invoice_lines.clear

      line_number = 0
      sorted_lines.each do |line|
        line.line_number = (line_number += 1)
        invoice.invoice_lines << line
      end
    end

    nil
  end

  # Does the actual sorting of the given invoice line array.
  # Override this method if your customer specific parser needs more complex sorting than can be done strictly
  # by an attribute array passed to sort_by.
  # If no sorting should be done, return nil
  def do_invoice_line_sorting lines
    sort_attributes = Array.wrap(invoice_line_attribute_sort_order)
    return nil if sort_attributes.blank?

    lines.sort_by {|t| sort_attributes.map {|attribute_name| t.public_send(attribute_name)} }
  end

  # Defines the sort ordering for invoice lines.  By default, this is by PO Number / PO Line Number as it appears
  # this is the default sorting on the GTN commercial invoice printout, and in general we wish to have the invoices
  # display in our systems / entry in the same order for ease of validation.
  #
  # If you wish to order the lines differently for a specific customer, simply override this
  # method and return an array of InvoiceLine attributes in the sort order you wish to use.
  #
  # Return nil or blank array if you want to leave the invoice lines numbered in XML document ordering
  #
  # Otherwise, if more complex sorting is needed, override the do_invoice_line_sorting method.
  def invoice_line_attribute_sort_order
    # The reason for ordering the lines according to the PO Number / PO Line Number is that it appears this matches 
    # the default way the commercial invoice printout from GT Nexus is generated.
    [:po_number, :po_line_number]
  end

  def find_or_create_invoice invoice_xml, bucket, key
    invoice = nil
    invoice_number = invoice_number(invoice_xml)
    inbound_file.reject_and_raise("All GT Nexus Invoice files must have an invoice number.") if invoice_number.blank?
    inbound_file.add_identifier :invoice_number, invoice_number
    invoice_sent_date = invoice_sent invoice_xml

    Lock.acquire("Invoice-#{invoice_number}") do
      i = Invoice.where(importer_id: importer.id, invoice_number: invoice_number).first_or_create!
      if process_file?(i, invoice_sent_date)
        invoice = i
      end
    end

    if invoice
      Lock.db_lock(invoice) do
        if process_file?(invoice, invoice_sent_date)
          set_invoice_file_metatdata invoice, invoice_sent_date, bucket, key
          inbound_file.set_identifier_module_info :invoice_number, Invoice, invoice.id, value: invoice.invoice_number
          yield invoice
        else
          invoice = nil
        end
      end
    end

    invoice
  end

  def set_invoice_file_metatdata invoice, invoice_sent_date, bucket, key
    invoice.last_exported_from_source = invoice_sent_date
    invoice.last_file_bucket = bucket
    invoice.last_file_path = key
  end

  def process_file? invoice, invoice_sent_date
    invoice.last_exported_from_source.nil? || invoice.last_exported_from_source <= invoice_sent_date
  end

  def set_invoice_information invoice, xml
    invoice.terms_of_payment = xml.text "freightPaymentCode"
    terms = xml.elements["invoiceTerms"]
    if terms
      invoice.invoice_date = date_value(terms, "Issue")
      invoice.terms_of_sale = terms.text "incotermCode"
      invoice.currency = terms.text "currencyCode"
      invoice.ship_mode = translate_ship_mode(terms.text "shipmentMethodCode")
      invoice.net_weight = BigDecimal(terms.text "packageDimensionSummary/totalNetWeight")
      invoice.net_weight_uom = terms.text "packageDimensionSummary/weightUnitCode"
      invoice.gross_weight = BigDecimal(terms.text "packageDimensionSummary/totalGrossWeight")
      invoice.gross_weight_uom = terms.text "packageDimensionSummary/weightUnitCode"
      invoice.volume = terms.text "packageDimensionSummary/totalGrossVolume"
      invoice.volume_uom = terms.text "packageDimensionSummary/volumeUnitCode"
    end
    
    set_additional_invoice_information invoice, xml
    nil
  end

  def set_invoice_totals invoice
    invoice.calculate_and_set_invoice_totals
    nil
  end

  def parse_invoice_lines invoice, invoice_xml
    REXML::XPath.each(invoice_xml, "invoiceItem") do |line_xml|
      parse_invoice_line(invoice, line_xml)
    end
  end

  def parse_invoice_line invoice, item_xml
    # See if the line is already present in the invoice and just update it if it is
    base_item = item_xml.elements["baseItem"]
    inbound_file.reject_and_raise("All invoiceItem elements must have a baseItem child element.") if base_item.nil?

    # It appears that GTN doesn't really have any sort of invoice line number in the XML 
    # The specs intimate that ItemSequenceNumber is the invoice line number, but it's not, its just a copy of the
    # order line number...that being the case...we're just going to destroy every line and rebuild the invoice every time.
    line = invoice.invoice_lines.build

    order_line = find_order_line(invoice, item_xml)
    if order_line
      line.order_line = order_line
      line.order = order_line.order
      line.product = order_line.product
      line.variant = order_line.variant
    elsif error_if_missing_order_line?
      inbound_file.reject_and_raise("Failed to find order line for Order Number '#{order_number(item_xml)}' / Line Number '#{order_line_number(item_xml)}'.")
    end

    line.po_number = order_number(item_xml)
    line.po_line_number = order_line_number(item_xml)
    line.unit_price = BigDecimal(item_xml.text("itemPrice/pricePerUnit").to_s)
    line.value_foreign = BigDecimal(item_xml.text("itemPrice/totalPrice").to_s)

    line.part_number = item_identifier_value(base_item, "BuyerNumber")
    line.hts_number = base_item.text "customsClassification/classificationNumber"
    line.part_description = item_identifier_value(base_item, "ShortDescription")
    line.quantity = BigDecimal(base_item.text("quantity").to_s)
    line.quantity_uom = base_item.text "unitOfMeasureCode"

    # By default, it doesn't look like GT Nexus includes a current exchange rate, so
    # the only time we can set this is if the invoice is billed in USD
    if invoice.currency.to_s.upcase == "USD"
      line.value_domestic = line.value_foreign
    end

    set_additional_invoice_line_information invoice, line, item_xml

    inbound_file.add_identifier(:po_number, line.po_number) unless line.po_number.blank?

    line
  end

  def find_order_line invoice, item_xml
    po_number = order_number(item_xml)
    return nil if po_number.blank?
    line_number = order_line_number(item_xml).gsub("-", "").to_i
    return nil if line_number == 0

    # By default, just look up the order line using the PO Number / Item Key (line number)
    # We may wish to look up the order and then cache it and iterate through it to find the line...rather than pull each line individually...for
    # now, this should work
    OrderLine.joins(:order).where(orders: {importer_id: invoice.importer.id, order_number: prefix_identifier_value(invoice.importer, po_number)}).where(line_number: line_number).first
  end

   # Extracts the corresponding orderDateValue from an orderDate element given the specified orderDateTypeCode
  def date_value date_parent, code
    date = nil
    val = date_parent.text "invoiceDate[invoiceDateTypeCode = '#{code}']/invoiceDateValue"
    if !val.blank?
      date = Date.iso8601(val) rescue nil
    end
    date
  end

  def party_map 
    {vendor: "party[partyRoleCode = 'Seller']", factory: "party[partyRoleCode = 'OriginOfGoods']", ship_to: "party[partyRoleCode = 'ShipmentDestination']"}
  end

  def invoice_sent invoice_xml
    time = time_zone.parse(invoice_xml.text("subscriptionEvent/eventDateTime")) rescue nil
    inbound_file.reject_and_raise("All GT Nexus Invoice documents must have a eventDateTime that is a valid timestamp.") if time.nil?
    time
  end

  def order_number item_xml
    item_xml.text "poNumber"
  end

  def order_line_number item_xml
    item_xml.text("itemKey")
  end

  def invoice_number invoice_xml
    invoice_xml.text "invoiceNumber"
  end

  def translate_ship_mode code
    case code.to_s.upcase
    when "A", "AE", "AF", "SE"
      "Air"
    when "S", "VE"
      "Ocean"
    when "T"
      "Truck"
    when "R"
      "Rail"
    else
      nil
    end
  end

end; end; end; end
