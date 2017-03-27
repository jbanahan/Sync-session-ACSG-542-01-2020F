require 'open_chain/custom_handler/fenix_nd_invoice_generator'
require 'open_chain/custom_handler/custom_file_csv_excel_parser'

module OpenChain; module CustomHandler; module Pvh; class PvhCaWorkflowParser
  include OpenChain::CustomHandler::CustomFileCsvExcelParser

  def initialize file
    @custom_file = file
  end

  def self.can_view? user
    (MasterSetup.get.system_code == "www-vfitrack-net" || Rails.env.development?) && user.company.master?
  end
  
  def can_view? user
    self.class.can_view? user
  end

  def process user
    check_extension(File.extname(@custom_file.path))
    parse 0, @custom_file
    parse 1, @custom_file
  end

  def excel_reader_options
    @excel_reader_options
  end

  private

  def parse sheet_no, file_contents
    set_sheet_number sheet_no
    invoice = prev_inv_num = curr_inv_num = prev_vendor_name = curr_vendor_name = nil
    invoice_rows = []
    foreach(file_contents) do |row, row_number| 
      row = stringify_elements row
      next if row[12].blank? || row_number < 3
      curr_vendor_name = row[11]
      curr_inv_num = row[12]
      next if inv_already_exists?(curr_inv_num, curr_vendor_name)
      if curr_inv_num != prev_inv_num
        complete_invoice invoice, invoice_rows, prev_vendor_name if invoice        
        invoice = CommercialInvoice.new(invoice_number: curr_inv_num, total_quantity_uom: 'CTN')
        invoice_rows = [row]
      else
        invoice_rows << row
      end
      prev_inv_num = curr_inv_num
      prev_vendor_name = curr_vendor_name
    end
    complete_invoice invoice, invoice_rows, curr_vendor_name if invoice
  end

  def stringify_elements row
    r = []
    row.each_with_index { |elem, i| r << ([19,24,26].include?(i) ? decimal_value(elem) : text_value(elem)) }
    r
  end
  
  def complete_invoice invoice, invoice_rows, vendor_name
    process_invoice invoice, invoice_rows
    DataCrossReference.create_pvh_invoice!(vendor_name, invoice.invoice_number)
    @inv_cache[vendor_name][invoice.invoice_number] = true
  end

  def process_invoice invoice, invoice_rows
    invoice.total_quantity = invoice_rows.inject(0) { |acc, nxt| acc += nxt[26].to_i; acc }
    invoice_rows.each do |row| 
      inv_line = create_inv_line invoice, row
      create_inv_tariff inv_line, row
    end
    OpenChain::CustomHandler::FenixNdInvoiceGenerator.generate invoice
  end

  def inv_already_exists? inv_num, vend_name
    @inv_cache ||= Hash.new { |h, k| h[k] = {} }
    if @inv_cache[vend_name][inv_num].nil?
      @inv_cache[vend_name][inv_num] = DataCrossReference.find_pvh_invoice(vend_name, inv_num)
    end
    @inv_cache[vend_name][inv_num]
  end

  def create_inv_line invoice, row
    invoice.commercial_invoice_lines.new(part_number: row[16], country_origin_code: row[10], po_number: row[15], quantity: row[19], unit_price: row[24])
  end

  def create_inv_tariff invoice_line, row
    hts_list = row[21..23].reject{ |hts| hts.to_s.length < 10 }
    descr = row[29..31].map{|d| d.strip.presence }.compact.join(" ")
    hts = hts_list.count == 1 ? hts_list[0] : nil
    invoice_line.commercial_invoice_tariffs.new(hts_code: hts, tariff_description: descr)
  end

  def set_sheet_number n
    @excel_reader_options = {sheet_number: n}
  end

  def check_extension ext
    if ![".xls", ".xlsx"].include? ext.downcase
      raise ArgumentError, "Only XLS and XLSX files are accepted." 
    end
  end

end; end; end; end