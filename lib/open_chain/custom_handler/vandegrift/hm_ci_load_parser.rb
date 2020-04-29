require 'open_chain/custom_handler/vandegrift/kewill_commercial_invoice_generator'
require 'open_chain/custom_handler/ci_load_handler'

 module OpenChain; module CustomHandler; module Vandegrift; class HmCiLoadParser < OpenChain::CustomHandler::CiLoadHandler

  def invalid_row? row
    row[0].to_s.blank? || row[2].to_s.blank?
  end

  def file_number_invoice_number_columns
    {file_number: 0, invoice_number: 2}
  end

  def parse_entry_header row
    OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadEntry.new text_value(row[0]), "HENNE", []
  end

  def parse_invoice_header entry, row
    inv = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoice.new text_value(row[2]), nil, []
    inv.non_dutiable_amount = (decimal_value(row[4]).presence || 0).abs
    if inv.non_dutiable_amount
      inv.non_dutiable_amount = inv.non_dutiable_amount.abs
    end
    inv.add_to_make_amount = decimal_value(row[5])

    inv
  end

  def parse_invoice_line entry, invoice, row
    l = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoiceLine.new
    l.foreign_value = decimal_value(row[3])
    l.hts = text_value row[7].to_s.gsub(".", "")
    l.country_of_origin = text_value row[8]
    l.quantity_1 = decimal_value(row[9])
    l.quantity_2 = decimal_value(row[10])
    l.cartons = decimal_value(row[11])
    l.gross_weight = decimal_value(row[12])
    l.mid = text_value row[13]
    l.part_number = text_value row[14]
    l.pieces = decimal_value(row[15])
    l.buyer_customer_number = text_value(row[16])
    l.seller_mid = text_value(row[17])
    l.cotton_fee_flag = text_value(row[18])
    l.spi = text_value(row[19])

    l
  end
end; end; end; end
