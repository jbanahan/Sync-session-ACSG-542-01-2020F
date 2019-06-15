require 'open_chain/report/report_helper'

module OpenChain; module InvoiceGeneratorSupport
  extend ActiveSupport::Concern
  include OpenChain::Report::ReportHelper
 
  def email_invoice invoice, addresses, subject, filename, detail_tempfile=nil
    invoice_tmp = create_xl_invoice invoice, filename
    OpenMailer.send_simple_html(addresses, subject, "Attached is the #{subject}", [invoice_tmp, detail_tempfile].compact).deliver_now  
    invoice_tmp.close
    detail_tempfile.close if detail_tempfile
  end

  def create_xl_invoice invoice, filename
    invoice_wb = create_invoice_wb invoice
    workbook_to_tempfile(invoice_wb, "report", file_name: "#{filename}.xls")
  end

  private

  def create_invoice_wb invoice
    wb, sheet = XlsMaker.create_workbook_and_sheet "invoice"
    create_header sheet, invoice
    create_lines sheet, invoice
    XlsMaker.set_column_widths sheet, [20,40,20,20,20,20]
    wb
  end

  def create_header sheet, invoice
    XlsMaker.insert_body_row sheet, 0, 0, ["Customer Name:", header_mfs[:vi_cust_name].process_export(invoice, nil)]
    XlsMaker.insert_body_row sheet, 2, 0, ["Invoice Date:", header_mfs[:vi_invoice_date].process_export(invoice, nil)]
    XlsMaker.insert_body_row sheet, 4, 0, ["Invoice Number:", header_mfs[:vi_invoice_number].process_export(invoice, nil)]
    XlsMaker.insert_body_row sheet, 6, 0, ["Currency:", header_mfs[:vi_invoice_currency].process_export(invoice, nil)]
    XlsMaker.insert_body_row sheet, 8, 0, ["Total Charges:", header_mfs[:vi_invoice_total].process_export(invoice, nil)]
  end

  def create_lines sheet, invoice
    XlsMaker.add_header_row sheet, 10, ["Line Number", "Description", "Quantity", "Unit", "Unit Price", "Charges"]
    invoice.vfi_invoice_lines.each_with_index { |l, i| create_line sheet, l, 11 + i }
  end

  def create_line sheet, invoice, row_number
    XlsMaker.insert_body_row sheet, row_number, 0, [line_mfs[:vi_line_number].process_export(invoice, nil),
                                                    line_mfs[:vi_line_charge_description].process_export(invoice, nil),
                                                    line_mfs[:vi_line_quantity].process_export(invoice, nil),
                                                    line_mfs[:vi_line_unit].process_export(invoice, nil),
                                                    line_mfs[:vi_line_unit_price].process_export(invoice, nil),
                                                    line_mfs[:vi_line_charge_amount].process_export(invoice, nil)]
  end

  def header_mfs
    @h_mfs ||= { vi_cust_name: ModelField.find_by_uid(:vi_cust_name),
                 vi_invoice_date: ModelField.find_by_uid(:vi_invoice_date),
                 vi_invoice_number: ModelField.find_by_uid(:vi_invoice_number),
                 vi_invoice_currency: ModelField.find_by_uid(:vi_invoice_currency),
                 vi_invoice_total: ModelField.find_by_uid(:vi_invoice_total) }
  end

  def line_mfs
    @l_mfs ||= { vi_line_number: ModelField.find_by_uid(:vi_line_number),
                 vi_line_charge_description: ModelField.find_by_uid(:vi_line_charge_description),
                 vi_line_quantity: ModelField.find_by_uid(:vi_line_quantity),
                 vi_line_unit: ModelField.find_by_uid(:vi_line_unit),
                 vi_line_unit_price: ModelField.find_by_uid(:vi_line_unit_price),
                 vi_line_charge_amount: ModelField.find_by_uid(:vi_line_charge_amount) }
  end
  
 
end; end
