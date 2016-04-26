require 'rexml/document'
require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/polo/polo_custom_definition_support'

module OpenChain; module CustomHandler; module Polo; class Polo850Parser
  extend IntegrationClientParser
  include PoloCustomDefinitionSupport

  def self.integration_folder
    "/home/ubuntu/ftproot/chainroot/polo/_polo_850"
  end

  def self.parse data, opts = {}
    self.new.parse data, opts
  end

  def initialize
    @cdefs ||= self.class.prep_custom_definitions [:ord_division, :ord_line_ex_factory_date, :ord_line_ship_mode, :ord_line_board_number]
  end

  def parse data, opts = {}  
    dom = REXML::Document.new(data)
    # Don't bother even attempting to parse Order cancellations
    return if cancellation?(dom)

    po_number = first_xpath_text dom, "/Orders/MessageInformation/MessageOrderNumber"
    if !po_number.blank?
      importer = Company.where(master: true).first
      raise "Unable to find Master RL account.  This account should not be missing." unless importer

      find_purchase_order(importer, po_number, find_source_system_datetime(dom)) do |po|
        po.last_file_bucket = opts[:bucket]
        po.last_file_path = opts[:key]

        parse_purchase_order dom, po
      end
    end
  end

  private
    def cancellation? dom
      first_xpath_text(dom, "/Orders/MessageInformation/OrderChangeType") == "01"
    end

    def find_purchase_order importer, po_number, source_system_export_date
      purchase_order = nil
      Lock.acquire(Lock::RL_PO_PARSER_LOCK, times: 3) do 
        po = Order.where(importer_id: importer.id, order_number: po_number, customer_order_number: po_number).includes(:order_lines).first_or_create!
        
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

    def parse_purchase_order dom, po
      # Pretty much all we're storing is the line level style, no sublines.
      # Store off the line numbers so we know which order lines to remove in cases of updates that removed po lines
      line_numbers = []

      REXML::XPath.each(dom, "/Orders/Lines/ProductLine") do |xml|
        line_number = xml.text("PositionNumber")
        next if line_number.blank?

        line_number = line_number.to_i

        line = po.order_lines.find(lambda {po.order_lines.build(:line_number => line_number)}) {|l| l.line_number == line_number}
        line_numbers << line_number

        # This is the number of UOM's ordered
        line.quantity = xml.text("ProductQuantityDetails/QuantityOrdered")
        line.unit_of_measure = xml.text("ProductQuantityDetails/ProductQuantityUOM")

        line.find_and_set_custom_value @cdefs[:ord_line_ex_factory_date], best_ex_factory(xml.text("ProductDates/DatesTimes[DateTimeType = '065']/Date"), xml.text("ProductDates/DatesTimes[DateTimeType = '118']/Date"))
        line.find_and_set_custom_value @cdefs[:ord_line_ship_mode], xml.text("Transport/ModeOfTransport")
        line.find_and_set_custom_value @cdefs[:ord_line_board_number], board_number(xml)

        # This is the RL Style regardless of whether the line is a Prepack, Set or standard line
        style = xml.text("ProductDetails3/ProductID/ProductIDValue")
        line.product = find_product(style)
      end

      # Every line will have the same season so we only need to find a single one in the document
      po.season = first_xpath_text(dom, "/Orders/Lines/ProductLine/ProductDescriptions[ItemCharacteristicsDescriptionCodeDesc = 'SNM']/ItemDescription")
      po.find_and_set_custom_value @cdefs[:ord_division], merchandise_division(dom)
      po.order_lines.select {|l| !(line_numbers.include?(l.line_number))}.map &:mark_for_destruction
      po.vendor = vendor(dom)
      po.save!

      po.create_snapshot User.integration

      po
    end

    def merchandise_division dom
      # Every line will have the same merchandise division so we only need to find a single one in the document
      merchandise_division = first_xpath_text dom, "/Orders/Lines/ProductLine/ProductDescriptions[ItemCharacteristicsDescriptionCodeDesc = 'MDV']/ItemDescription"

      # If the 850 consisted solely of prepack lines then the Merchandise division is at the subline level
      unless merchandise_division
        merchandise_division = first_xpath_text dom, "/Orders/Lines/ProductLine/SubLine/ProductDescriptions[ItemCharacteristicsDescriptionCodeDesc = 'MDV']/ItemDescription"
      end

      merchandise_division
    end

    def board_number xml
      board = first_xpath_text(xml, "ProductDescriptions[ItemCharacteristicsDescriptionCodeDesc = 'BRD']/ItemDescription")

      # Board numbers can differ for each distinct size in the prepack, so make sure we list them all
      if board.blank?
        board = REXML::XPath.each(xml, "SubLine/ProductDescriptions[ItemCharacteristicsDescriptionCodeDesc = 'BRD']/ItemDescription").map {|n| n.text.presence || nil}.compact.uniq.join(", ")
      end

      board
    end

    def vendor xml
      vendor_xml = REXML::XPath.first(xml, "/Orders/Parties[NameAddress/PartyID/PartyIDType = 'SU']/NameAddress")
      vendor_id = vendor_xml.text("PartyID/PartyIDValue").strip unless vendor_xml.nil?
      company = nil
      if !vendor_id.blank?
        company = Company.vendors.where(system_code: vendor_id).first_or_initialize
        # Only update vendor information if the vendor didn't exist
        unless company.persisted?
          company.name = vendor_xml.text("PartyID/PartyIDTypeDesc")
          company.save!
        end
      end
      company
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

    def best_ex_factory date_1, date_2
      # So, the first date is the "original" ex factory date, the second is the updated one.
      # Always go w/ the updated one if it's present
      date_1 = date_1.blank? ? nil : Date.strptime(date_1, "%Y-%m-%d") rescue nil
      date_2 = date_2.blank? ? nil : Date.strptime(date_2, "%Y-%m-%d") rescue nil

      date_2 ? date_2 : date_1
    end

    def first_xpath_text dom, expression 
      text = nil
      node = REXML::XPath.first(dom, expression)
      if node
        text = node.text
      end

      text
    end

    def find_product style
      # Make sure we're using the same Lock that is used in file import processor, since that'll be the process we're 
      # competing against potentially when creating these
      Lock.acquire("Product-#{style}") do
        # We don't want to set the importer, because RL doesn't set it on 99% of their styles when
        # they are uploaded via worksheets
        Product.where(unique_identifier: style).first_or_create!
      end
    end


end; end; end; end