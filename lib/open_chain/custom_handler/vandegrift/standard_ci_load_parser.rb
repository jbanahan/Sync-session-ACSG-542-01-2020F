require 'open_chain/custom_handler/vandegrift/kewill_commercial_invoice_generator'
require 'open_chain/custom_handler/ci_load_handler'

module OpenChain; module CustomHandler; module Vandegrift; class StandardCiLoadParser < OpenChain::CustomHandler::CiLoadHandler

  def invalid_row? row
    row[0].to_s.blank? || row[1].to_s.blank? || row[2].to_s.blank?
  end

  def file_number_invoice_number_columns
    {file_number: 0, invoice_number: 2}
  end

  def parse_entry_header row
    OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadEntry.new text_value(row[0]), text_value(row[1]), []
  end

  def parse_invoice_header entry, row
    OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoice.new text_value(row[2]), date_value(row[3]), []
  end

  def parse_invoice_line entry, invoice, row
    l = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoiceLine.new
    l.country_of_origin = text_value row[4]
    l.part_number = text_value row[5]
    l.pieces = decimal_value(row[6])
    l.mid = text_value row[7]
    l.hts = text_value row[8].to_s.gsub(".", "")
    l.cotton_fee_flag = text_value row[9]
    l.foreign_value = decimal_value(row[10])
    l.quantity_1 = decimal_value(row[11])
    l.quantity_2 = decimal_value(row[12])
    l.gross_weight = decimal_value(row[13])
    l.po_number = text_value(row[14])
    l.cartons = decimal_value(row[15])
    l.first_sale = decimal_value row[16]

    mmv_ndc = decimal_value(row[17])
    if mmv_ndc.nonzero?
      # So, pperations was / is using this field for two different purposes (WTF)...when the value
      # is negative they're expecting it to go to the non-dutiable field in kewill, when it's positive
      # it should go to the add to make amount.
      if mmv_ndc > 0
        l.add_to_make_amount = mmv_ndc
      else
        l.non_dutiable_amount = (mmv_ndc * -1)
      end
    end

    l.department = decimal_value(row[18])
    l.spi = text_value(row[19])
    l.buyer_customer_number = text_value(row[20])
    l.seller_mid = text_value(row[21])
    l.spi2 = text_value(row[22])

    l
  end
end; end; end; end
