require 'open_chain/fixed_position_generator'
require 'open_chain/ftp_file_support'

module OpenChain; module CustomHandler; class KewillCommercialInvoiceGenerator < OpenChain::FixedPositionGenerator
  include OpenChain::FtpFileSupport

  CiLoadEntry ||= Struct.new :file_number, :customer, :invoices
  CiLoadInvoice ||= Struct.new :invoice_number, :invoice_date, :invoice_lines
  CiLoadInvoiceLine ||= Struct.new :part_number, :country_of_origin, :gross_weight, :pieces, :hts, :foreign_value, :quantity_1, :quantity_2, :po_number, :first_sale, :department, :spi, :ndc_mmv, :cotton_fee_flag, :mid, :cartons


  def initialize
    super(numeric_pad_char: '0', blank_date_fill_char: '0', string_output_encoding: "ASCII")
  end

  def generate_and_send entries 
    entries.each do |entry|
      Tempfile.open(["CI_Load_#{entry.file_number}_", ".txt"]) do |file|
        file.binmode
        generate(file, entry)
        file.rewind

        ftp_file file
      end
    end
  end

  def generate io, entry
    entry.invoices.each do |invoice|
      generate_header io, entry, invoice
      line_number = 0
      invoice.invoice_lines.each do |invoice_line|
        generate_invoice_line io, entry, invoice, invoice_line, (line_number += 1)
      end
    end
  end

  def generate_header io, entry, invoice
    io << "C0"
    io << str(entry.file_number, 15)
    io << str(invoice.invoice_number, 22)
    io << date(invoice.invoice_date)
    io << "".ljust(68) # Master/House/Sub/Sub-Sub Bills, Match Shipment, Match Entry Fields
    io << str(entry.customer, 10)
    io << "".ljust(2) # Invoice Type
    io << "USD"
    io << " " # Fixed Exchange Rate
    io << "01000000" # Exchange Rate
    io << "".ljust(39) # Location / Location of Goods
    io << "".ljust(83, '0') # Num Inv Lines - Freight Amount
    io << "".ljust(3) # Prorate Freight Amount - Prorate Cash Discount
    io << "".ljust(30, '0') # Discount % - Add To Make Amount
    io << "".ljust(245) # Commercial Invoice Desc 1 - Customer Reference
    io << "".ljust(12, '0') # Qty
    io << "".ljust(6) # UOM
    io << "".ljust(20, '0') # Gross Weight - Export Date
    io << "".ljust(527) # Country Origin - Payment Terms 5
    io << "".ljust(23, '0') # Net Allowance Charge - Charges
    io << "  " # Action Request Code
    io << "".ljust(26, '0') # Edi Assigned File - Date Printed
    io << "  " # Location Qualifier
    io << "".ljust(12, '0') # Other Amount
    io << "".ljust(11) # Prorate Non Dutiable - Deduct Duty Fees
    io << "".ljust(11, '0') # Discount %
    io << "".ljust(10) # Agency Code
    io << "".ljust(12, '0') # Landed Weight
    io << " " # Landed Weight UOM
    io << "00" # Entry Type
    io << "".ljust(135) # PO # - User Field 5
    io << "".ljust(20, '0') # Packing Charge - Insurance Amount
    io << "".ljust(280) # Document Prepared By - Freight Ship Desc 3
    io << "".ljust(12, '0') # Net Weight
    io << "  " # Update Action Code - Invoice Request Response
    io << "00" # Payment Terms Type 
    io << " " # AII Transaction
    io << "".ljust(95, '0') # CI # Lines - Total Value US Duty
    io << "".ljust(32) # Declarant
    io << "".ljust(8, '0') # Date Declarant
    io << "".ljust(399) # Already Send AII - EDI Upload Rec 2
    io << "\n"

  end

  def generate_invoice_line io, entry, invoice, invoice_line, line_counter
    io << "C1"
    io << str(entry.file_number, 15)
    io << str(invoice.invoice_number, 22)
    io << date(invoice.invoice_date)
    io << num(line_counter * 10, 5)
    io << "".ljust(78) # Master/House/Sub/Sub-Sub Bills, Match Shipment, Match Entry Fields, Customer Number
    io << str(invoice_line.part_number, 30)
    io << "".ljust(110) # Assembler - Serial Number
    io << "".ljust(12, '0') # Quantity
    io << "      " # Quantity UOM
    io << "".ljust(8, '0') # Date Export
    io << str(invoice_line.country_of_origin, 2) 
    io << "  " # Country of Export
    io << "00000" # Port of Lading
    io << num(invoice_line.gross_weight, 12)
    io << "      " # Kilos Pounds
    io << "".ljust(11, '0')
    io << "M3    "
    io << num(invoice_line.pieces, 12, 3, numeric_strip_decimals: true)
    io << "PCS   "
    io << "".ljust(15, '0') # Unit Price
    io << "".ljust(56) # UOM Unit Price - Seal Number
    io << str(invoice_line.hts, 10)
    io << num(invoice_line.foreign_value, 13, 2, numeric_strip_decimals: true)
    io << num(invoice_line.quantity_1, 12, 2, numeric_strip_decimals: true)
    io << "   " # UOM 1
    io << num(invoice_line.quantity_2, 12, 2, numeric_strip_decimals: true)
    io << "   " # UOM 2
    io << "".ljust(12, '0') # Quantity 3
    io << "   " # UOM 3
    io << str(invoice_line.po_number, 35)
    io << str(invoice_line.po_number, 35)
    io << "".ljust(8, '0') # PO Date
    io << "".ljust(15) # Filler 2 - PO Rel #
    io << "".ljust(12, '0') # PO Quantity
    io << "".ljust(12) # Model #
    io << num(invoice_line.first_sale, 12, 2, numeric_left_align: true, strip_insignificant_zeros: true, numeric_pad_char: ' ')
    io << "".ljust(148) # Related Parties - Action Request code
    io << "".ljust(31, '0') # Edi Assigned File - Detail Line #
    io << "".ljust(60) # Product Line - Domestic Destination
    io << num(invoice_line.department, 6)
    io << "".ljust(11, '0') # Charges
    io << "".ljust(14) # Penalty Type - User Entered Weight
    io << str(invoice_line.spi, 2)
    io << " " # SPI Secondary
    io << "".ljust(12, '0') # Non-Dutiable Amount
    io << num(invoice_line.ndc_mmv, 12, 2, numeric_strip_decimals: true)
    io << "".ljust(48, '0') # Other Amount - Freight Amount
    io << "".ljust(32) # Convert Non-Dutiable Amount - Stat Tariff Number
    io << "".ljust(13, '0') # Stat Tariff Value
    io << "".ljust(248) # Tradecode - Visa License Quantity
    io << "".ljust(9, '0') # Visa License Quantity
    io << "".ljust(12) # Visa License Qty UOM - Visa #
    io << "".ljust(11, '0') # Visa Date - Category #
    io << "".ljust(357) # User Field 1 - Ftz Zone Status
    io << "".ljust(49, '0') # FTZ Priv Status Date - Price Factor
    io << "   " # Released Entry Filer
    io << "".ljust(9, '0') # Released File #
    io << "".ljust(11) # NAFTA NC - Agriculture License #
    exemption = ["Y", "YES", "TRUE", "1"].include?(invoice_line.cotton_fee_flag.to_s.upcase) ? "999999999" : "000000000"
    io << str(exemption, 9)
    io << str(invoice_line.mid, 15)
    io << "".ljust(77, '0') # ADA Special Deposit - Payment Terms Type
    io << "".ljust(30) # Dock Code
    io << "00" # How Rated
    io << "".ljust(58) # Price Currency - PO Item
    io << "".ljust(14, '0') # PO Price Count - PO Effective Date
    io << "".ljust(114) # Contract UOM - CO Calendar Year
    io << "".ljust(9, '0') # CO Document Number
    io << "".ljust(24) # CO Alt Duns - MA Let Duns
    io << "".ljust(17, '0') # Price 17
    io << "".ljust(52) # Selling Source - Steel License
    io << num(invoice_line.cartons, 12, 2, numeric_strip_decimals: true)
    io << "".ljust(44) # TPL Flag - MID
    io << "\n"
  end

  def ftp_credentials
    connect_vfitrack_net('to_ecs/ci_load')
  end

end; end; end;
