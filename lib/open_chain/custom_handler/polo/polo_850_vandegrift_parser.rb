require 'rexml/document'
require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/polo/polo_business_logic'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

# This class is solely for handling 850 XML documents intended to populate information into the VFI Track (Vandegrift)
# application instance (.ie not RL one)
module OpenChain; module CustomHandler; module Polo; class Polo850VandegriftParser
  include OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include OpenChain::CustomHandler::Polo::PoloBusinessLogic

  RL_BUYER_MAP ||= {
    '0200011989' => '806167003RM0001',
    '0200011987' => '866806458RM0001',
    '0200016789' => '806167003RM0002'
  }

  def self.parse_file data, log, opts = {}
    self.new.parse_file data, log, opts
  end

  def self.integration_folder
    ["www-vfitrack-net/_polo_850", "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_polo_850"]
  end

  def parse_file data, log, opts = {}
    dom = REXML::Document.new(data)
    # Don't bother even attempting to parse Order cancellations
    return if cancellation?(dom)

    save_merchandise_description dom

    # For PO storage purposes we can map the Buyer (BY) entity on the XML to the Polo Importer.  At this point, we're handling the following Importers
    # Buyer ID 0200011989 = RL Canada (Fenix Cust No) -> 806167003RM0001
    # Buyer ID 0200011987 = Club Monaco (Fenix Cust No) -> 866806458RM0001
    # These are the only Buyers we've received data for in the months leading up to this project.  New buyer ids we'll handle on a case-case basis.
    buyer_id = first_xpath_text dom, "/Orders/Parties/NameAddress/PartyID[PartyIDType = 'BY']/PartyIDValue"
    po_number = first_xpath_text dom, "/Orders/MessageInformation/MessageOrderNumber"

    log.add_identifier InboundFileIdentifier::TYPE_PO_NUMBER, po_number

    if (importer_number = RL_BUYER_MAP[buyer_id]) && !po_number.blank?
      importer = Company.with_fenix_number(importer_number).first
      log.reject_and_raise "Unable to find Fenix Importer for importer number #{importer_number}.  This account should not be missing." if importer.nil?

      log.company = importer

      find_purchase_order(importer, po_number, find_source_system_datetime(dom)) do |po|
        po.last_file_bucket = opts[:bucket]
        po.last_file_path = opts[:key]

        log.set_identifier_module_info InboundFileIdentifier::TYPE_PO_NUMBER, Order.to_s, po.id

        parse_purchase_order dom, po
      end
    elsif importer_number.blank?
      log.reject_and_raise "Unknown Buyer ID #{buyer_id} found in PO Number #{po_number}.  If this is a new Buyer you must link this number to an Importer account."
    end
  end

  def cdefs 
    @cdefs ||= self.class.prep_custom_definitions [:ord_invoicing_system, :prod_part_number, :ord_line_ex_factory_date, :ord_division]
  end

  private

    def cancellation? dom
      first_xpath_text(dom, "/Orders/MessageInformation/OrderChangeType") == "01"
    end

    def save_merchandise_description dom
      # The only thing we're doing here is finding the PO # and then extracting one of the Merchandise Division
      # lines from the details to save to the DataCrossReference table, so the SAP invoice generator will
      # have that cross reference to utilize when finding the profit center to bill.
      po_number = first_xpath_text dom, "/Orders/MessageInformation/MessageOrderNumber"

      unless po_number.nil? || sap_po?(po_number)
        merch_div_no = merchandise_division(dom, true)
       
        if merch_div_no
          DataCrossReference.transaction do 
            cr = DataCrossReference.where(cross_reference_type: DataCrossReference::RL_PO_TO_BRAND, key: po_number).first_or_create! value: merch_div_no

            # I'm relying here on the save being a no-op in cases where we've created the cross-reference - since the value isn't dirty.
            cr.value = merch_div_no
            cr.save!
          end
        end
      end
    end

    def merchandise_division dom, numeric
      merch_attribute = numeric == true ? "ItemCharacteristicsDescriptionCode" : "ItemDescription"

      # Every line will have the same merchandise division so we only need to find a single one in the document
      merchandise_division = first_xpath_text dom, "/Orders/Lines/ProductLine/ProductDescriptions[ItemCharacteristicsDescriptionCodeDesc = 'MDV']/#{merch_attribute}"

      # If the 850 consisted solely of prepack lines then the Merchandise division is at the subline level
      unless merchandise_division
        merchandise_division = first_xpath_text dom, "/Orders/Lines/ProductLine/SubLine/ProductDescriptions[ItemCharacteristicsDescriptionCodeDesc = 'MDV']/#{merch_attribute}"
      end

      merchandise_division
    end

    def find_purchase_order importer, po_number, source_system_export_date
      purchase_order = nil
      Lock.acquire("Order-#{po_number}") do 
        po = Order.where(importer_id: importer.id, customer_order_number: po_number).includes(:order_lines).first_or_create! do |order|
          order.order_number = order.create_unique_po_number
        end
        
        if valid_export_date? po, source_system_export_date
          # Set the source system export date (which is really the timestamp for when we received the EDI) while
          # we've totally locked out other processes.  This ensures if we're processing multiple versions of the same
          # PO at the same time that we then mark off only the most up to date version in the DB in a mutually exclusive
          # way.
          po.update_column(:last_exported_from_source, source_system_export_date)
          purchase_order = po
        end
      end

      return unless purchase_order

      Lock.with_lock_retry(purchase_order) do
        # the with_lock call actually reloads the po from the DB, so make sure that we haven't actually
        # gotten a newer version of the PO via the reload
        yield purchase_order if valid_export_date? purchase_order, source_system_export_date
      end
    end

    def valid_export_date? po, source_system_export_date
      po.last_exported_from_source.nil? ||  po.last_exported_from_source <= source_system_export_date
    end

    def find_source_system_datetime dom
      # This information is inserted by our EDI parsing engine.  It represents the time the file was processed by the engine
      date = first_xpath_text(dom, "/Orders/MessageInformation/MessageDate").to_s
      time = first_xpath_text(dom, "/Orders/MessageInformation/MessageTime").to_s
      if time.length == 4
        time = time[0..1] + ":" + time[2..-1]
      end

      ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse (date + " " + time)
    end

    def parse_purchase_order dom, po
      # Pretty much all we're storing is the line level style, no sublines.
      # This is primarily so that we can validate in the CA commercial invoice that the po/part numbers keyed correspond to actual
      # PO / Part Numbers.

      # Store off the line numbers so we know which order lines to remove in cases of updates that removed po lines
      line_numbers = []

      REXML::XPath.each(dom, "/Orders/Lines/ProductLine") do |xml|
        line_number = xml.text("PositionNumber")
        next if line_number.blank?

        line_number = line_number.to_i

        line = po.order_lines.find(lambda {po.order_lines.build(:line_number => line_number)}) {|l| line = l if l.line_number == line_number}
        line_numbers << line_number

        # This is the RL Style regardless of whether the line is a Prepack, Set or standard line
        style = xml.text("ProductDetails3/ProductID/ProductIDValue")

        # This is the number of UOM's ordered
        line.quantity = xml.text("ProductQuantityDetails/QuantityOrdered")

        line.find_and_set_custom_value cdefs[:ord_line_ex_factory_date], best_ex_factory(xml.text("ProductDates/DatesTimes[DateTimeType = '065']/Date"), xml.text("ProductDates/DatesTimes[DateTimeType = '118']/Date"))
       
        # Because we're storing these products in our system (which holds other importer product data), we need to preface the 
        # table's unique identifier column with the importer identifier.
        product = Product.where(importer_id: po.importer_id, unique_identifier: po.importer.fenix_customer_identifier + "-" + style).first_or_initialize
        
        # We only need to save product data the very first time we encounter it
        if product.new_record?
          # since we're only storing a minimal amount of information, also set the style into the name since
          # the PO screen displays the product name on it
          product.name = style 
          # This info tells us if the line is a Set (ST), Prepack (AS), or standard (EA or PR [pair])
          product.unit_of_measure = xml.text("ProductQuantityDetails/ProductQuantityUOM")

          # Part Number is the importer's unique identifier, but not the system unique identifier
          product.find_and_set_custom_value cdefs[:prod_part_number], style
          product.save!
        end
        line.product = product
      end

      po.find_and_set_custom_value cdefs[:ord_division], merchandise_division(dom, false)
      # If we have a REF w/ Qualifier of 9V w/ a value field of TC or TCF, then mark the order as having the invoice system as Tradecard.
      invoicing_system = (["TC", "TCF"].include?(first_xpath_text(dom, "/Orders/MessageReferences/References[ReferenceType = '9V']/ReferenceValue")) ? "Tradecard" : "")
      po.find_and_set_custom_value cdefs[:ord_invoicing_system], invoicing_system

      po.order_lines.select {|l| !(line_numbers.include?(l.line_number))}.map &:mark_for_destruction
      po.save!

      po
    end

    def first_xpath_text dom, expression 
      text = nil
      node = REXML::XPath.first(dom, expression)
      if node
        text = node.text
      end

      text
    end

    def best_ex_factory date_1, date_2
      # So, the first date is the "original" ex factory date, the second is the updated one.
      # Always go w/ the updated one if it's present
      date_1 = date_1.blank? ? nil : Date.strptime(date_1, "%Y-%m-%d") rescue nil
      date_2 = date_2.blank? ? nil : Date.strptime(date_2, "%Y-%m-%d") rescue nil

      date_2 ? date_2 : date_1
    end
end; end; end; end
