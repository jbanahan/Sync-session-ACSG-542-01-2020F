require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/vandegrift/kewill_shipment_xml_sender_support'
require 'open_chain/custom_handler/nokogiri_xml_helper'

module OpenChain; module CustomHandler; module Vandegrift; class VandegriftPuma7501Parser
  include OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::Vandegrift::KewillShipmentXmlSenderSupport
  include OpenChain::CustomHandler::NokogiriXmlHelper

  def self.parse(data, opts = {})
    self.new.parse(data, opts)
  end

  def parse data, _opts = {}
    xml_data = Nokogiri::XML(data)
    shipments = process_file(xml_data)
    generate_and_send_invoice_xml(shipments)
  end

  def file_number(xml)
    parse_date(et(xml, "STATEMENT_DATE")).strftime("%Y%m%dP")
  end

  def process_file(data)
    shipment = CiLoadEntry.new
    shipment.invoices = []

    invoice_xml = first_xpath(data, "/CUSTOMS_ENTRY_FILE/ENTRY")

    shipment = generate_shipment(invoice_xml, shipment)
    shipment.invoices = []
    shipment.invoices << generate_invoice(invoice_xml)
    # There is only one invoice per 7501 so we can safely assume the first invoice owns all invoice_lines
    shipment.invoices.first.invoice_lines = generate_invoice_lines(data)

    shipment
  end

  def parse_date(date)
    return nil if date.nil?

    Date.strptime(date, "%m/%d/%Y")
  end

  private

  def generate_shipment(invoice_xml, shipment)
    shipment.customer = "PUMA"
    shipment.file_number = file_number(invoice_xml)
    inbound_file.add_identifier(:file_number, shipment.file_number)

    shipment
  end

  def generate_invoice_lines(data)
    lines = []

    xpath(data, "CUSTOMS_ENTRY_FILE/ENTRY/INVOICE/ITEM") do |item|
      line = CiLoadInvoiceLine.new

      next if item.blank?

      line.part_number = et(item, "ITEM_NO")
      line.country_of_origin = et(item, "COUNTRY_OF_ORIGIN")
      line.gross_weight = et(item, "GROSS_WGT")
      line.hts = et(item, "HTS")
      line.foreign_value = et(item, "HTS_VALUE")
      line.quantity_1 = et(item, "QTY_1")
      line.quantity_2 = et(item, "QTY_2")
      line.mid = et(item, "MANUFACTURERS_ID_NO")
      line.spi = et(item, "SPECIAL_PROGRAMS_INDICATOR_1")
      line.spi2 = et(item, "SPECIAL_PROGRAMS_INDICATOR_2")
      line.charges = et(item, "CHARGES")

      # FTZ fields are only to be populated if the status is "P".
      ftz_status = et(item, "FTZ_STATUS")
      if ftz_status == "P"
        line.ftz_zone_status = ftz_status
        line.ftz_priv_status_date = parse_date(et(item, "FTZ_DATE"))
        line.ftz_quantity = et(item, "FTZ_MANIFEST_QTY")
      end

      supplemental_tariff = et(item, "ADDITIONAL_HTS")
      if supplemental_tariff.present?
        tar_sup = CiLoadInvoiceTariff.new
        tar_sup.hts = supplemental_tariff
        tar_sup.foreign_value = et(item, "ADDITIONAL_HTS_VALUE")

        # Due to the way KewillShipmentXmlSupport handles tariff info, we also need to add a tariff record
        # for the primary tariff.  The support class automatically makes this from the line record in the
        # event there are not tariff_lines under the line.
        tar_prime = CiLoadInvoiceTariff.new
        tar_prime.hts = line.hts
        tar_prime.gross_weight = line.gross_weight
        tar_prime.foreign_value = line.foreign_value
        tar_prime.spi = line.spi
        tar_prime.spi2 = line.spi2

        line.tariff_lines = [tar_sup, tar_prime]
      end

      lines << line
    end

    lines
  end

  def generate_invoice(invoice_xml)
    invoice = CiLoadInvoice.new

    invoice.file_number = file_number(invoice_xml)
    invoice.invoice_number = et(invoice_xml, "ENTRY_NO")
    invoice.invoice_date = parse_date(et(invoice_xml, "STATEMENT_DATE"))
    invoice.currency = "USD"
    invoice
  end
end; end; end; end