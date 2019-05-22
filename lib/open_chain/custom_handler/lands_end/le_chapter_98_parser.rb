require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/custom_handler/vandegrift/kewill_shipment_xml_support'
require 'open_chain/custom_handler/vandegrift/kewill_commercial_invoice_generator'
require 'open_chain/s3'
require 'open_chain/custom_handler/custom_file_csv_excel_parser'

module OpenChain; module CustomHandler; module LandsEnd; class LeChapter98Parser
  include OpenChain::CustomHandler::Vandegrift::KewillShipmentXmlSupport
  include CustomFileCsvExcelParser

  def initialize file
    @custom_file = file
  end

  def can_view? user
    MasterSetup.get.custom_feature?("alliance") && user.company.master?
  end

  def process user, parameters
    csv = foreach(@custom_file, skip_headers:true, skip_blank_lines: true)
    invoice_lines = {}
    invoices = []

    sorted_csv = sort_csv(csv)
    sorted_csv.each do |lines|
      roll_up_hash = generate_initial_hash(lines)
      sum_roll_up(roll_up_hash, lines)

      invoice_lines[roll_up_hash['inv_number']] ||= []
      invoice_lines[roll_up_hash['inv_number']] << generate_invoice_line(roll_up_hash)
    end

    invoice_lines.each do |key, value|
      invoices << generate_invoice(key, Time.zone.now, value)
    end

    entry = generate_entry(invoices, parameters['file_number'])
    OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator.new.generate_and_send entry
  end

  def generate_entry(invoices, file_number)
    entry = CiLoadEntry.new
    entry.file_number = file_number
    entry.customer = 'LANDS1'
    entry.invoices = invoices
    entry
  end

  def generate_invoice(inv_number, date, invoice_lines)
    invoice = CiLoadInvoice.new
    invoice.invoice_number = inv_number
    invoice.invoice_date = date
    invoice.invoice_lines = invoice_lines
    invoice
  end

  def generate_invoice_line(roll_up_hash)
    line = CiLoadInvoiceLine.new
    line.part_number = roll_up_hash['part_style']
    line.country_of_origin = roll_up_hash['country_origin']
    line.pieces = roll_up_hash['pcs']
    line.hts = roll_up_hash['tariff_number']
    line.foreign_value = roll_up_hash['value']
    line.mid = roll_up_hash['mid']
    line
  end

  def generate_initial_hash(lines)
    roll_up_hash = {}
    roll_up_hash['inv_number'] = lines.first[2]
    roll_up_hash['inv_date'] = Time.zone.now
    roll_up_hash['country_origin'] = lines.first[19]
    roll_up_hash['part_style'] = lines.first[12]
    roll_up_hash['pcs'] = 0
    roll_up_hash['mid'] = 'XORUSFAR6220LAS'
    roll_up_hash['tariff_number'] = '9801002600'
    roll_up_hash['cotton_fee'] = ''
    roll_up_hash['value'] = 0
    roll_up_hash['qty1'] = ''
    roll_up_hash['qty2'] = ''
    roll_up_hash['gr_wt'] = ''
    roll_up_hash['first_sale'] = ''
    roll_up_hash
  end

  def sum_roll_up(roll_up_hash, lines)
    roll_up_hash['pcs'] = lines.inject(0) { |sum, line | sum + line[20].to_d }
    roll_up_hash['value'] = lines.inject(0) {|sum, line| sum + line[22].to_d }
  end

  def sort_csv(csv)
    sorted = csv.sort { |line, line2| line[19] <=> line2[19] }.group_by { |line| [line[2], line[19]] }

    # sorting returns a hash so we just want the values.
    sorted.values
  end
end; end; end; end
