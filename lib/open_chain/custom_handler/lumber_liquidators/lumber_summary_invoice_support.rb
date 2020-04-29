module OpenChain; module CustomHandler; module LumberLiquidators; module LumberSummaryInvoiceSupport

  def generate_summary_invoice_page sheet, invoices, summary_date
    generate_summary sheet, invoices, summary_date
  end

  def generate_supplemental_summary_page sheet, invoice
    generate_summary sheet, [invoice], nil
  end


  def generate_summary sheet, invoices, summary_date
    bold_format = XlsMaker.create_format "Bolded", weight: :bold
    bold_date_format = XlsMaker.create_format "Bold Date", weight: :bold, number_format: "MMMM D, YYYY", horizontal_align: :left
    invoice_amount_format = XlsMaker.create_format "Invoice Amount", number_format: "[$$-409]#,##0.00;[RED]-[$$-409]#,##0.00"
    invoice_total_format = XlsMaker.create_format "Invoice Total", weight: :bold, number_format: "[$$-409]#,##0.00;[RED]-[$$-409]#,##0.00"

    column_widths = []
    # Adjust the width of the first column, the column width calculation in XlsMaker has a limiter by default that only allows
    # 23 at most, we want more than that
    XlsMaker.calc_column_width sheet, 0, column_widths, 35
    row = -1
    XlsMaker.add_body_row sheet, (row += 1), ["Vandegrift Forwarding Co., Inc"], column_widths, true, format: bold_format
    if summary_date
      XlsMaker.add_body_row sheet, (row += 1), ["Statement of Account as of"], column_widths, true, format: bold_format
      XlsMaker.insert_body_row sheet, row, 1, [summary_date], column_widths, true, format: bold_date_format
    end

    XlsMaker.add_body_row sheet, (row += 1), ["Company", "Lumber Liquidators"], column_widths, true, format: bold_format
    XlsMaker.add_header_row sheet, (row += 2), ["Invoice", "Invoice Date", "Invoice Amount"], column_widths

    total = BigDecimal("0")
    invoices.each_with_index do |invoice, x|
      inv_total = invoice.invoice_total.presence || BigDecimal("0")
      total += inv_total

      invoice_cell = invoice.entry ? XlsMaker.create_link_cell(invoice.entry.excel_url, invoice.invoice_number.to_s) : invoice.invoice_number
      XlsMaker.add_body_row sheet, (row += 1), [invoice_cell, invoice.invoice_date], column_widths
      XlsMaker.insert_body_row sheet, (row), 2, [inv_total], column_widths, true, format: invoice_amount_format
    end

    row += 2
    XlsMaker.add_body_row sheet, row, ["", "Total:"], column_widths, true, format: bold_format
    XlsMaker.insert_body_row sheet, row, 2, [total], column_widths, true, format: invoice_total_format


    nil
  end


end; end; end; end;