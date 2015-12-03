module SummaryStatementsHelper

  def render_summary_xls ss
    wb = XlsMaker.create_workbook "Statement"
    sheet = wb.worksheet 0
    add_statement_header sheet, ss, 0
    
    header_type = :us
    if ss
      unless ss.broker_invoices.empty?
        header_type = :ca if ss.broker_invoices.first.entry.canadian?
      end
    end

    add_chart sheet, ss, header_type, 4   
    wb
  end

  private

    def add_statement_header sheet, statement, start_row
      XlsMaker.insert_body_row sheet, start_row, 0, ["Company:", statement.customer.name]
      XlsMaker.insert_body_row sheet, start_row + 1, 0, ["Statement:", statement.statement_number]
      XlsMaker.insert_body_row sheet, start_row + 2, 0, ["Total:", statement.total]
      XlsMaker.insert_body_row sheet, start_row + 3, 0, [""]
    end

    def add_chart sheet, statement, header_type, start_row
      row = start_row
      XlsMaker.add_header_row sheet, row, chart_header(header_type)
      if statement.broker_invoices.length > 0
        statement.broker_invoices.each do |bi|
          XlsMaker.add_body_row sheet, (row+=1), [bi.invoice_number, 
                                                  bi.invoice_date, 
                                                  bi.invoice_total, 
                                                  bi.entry.importer.name, 
                                                  bi.entry.entry_number, 
                                                  bi.bill_to_name,
                                                  header_type == :ca ? bi.entry.k84_month : bi.entry.release_date,
                                                  header_type == :ca ? bi.entry.cadex_accept_date : bi.entry.monthly_statement_due_date,
                                                  XlsMaker.create_link_cell(broker_invoice_url bi)]
        end
      end
    end

    def chart_header header_type
      base_headers = ["Invoice Number", "Invoice Date", "Amount", "Customer Name", "Entry Number", "Bill To Name"]
      us_headers = ["Release Date", "PMS Month"]
      ca_headers = ["K84 Month", "Cadex Accept Date"]

      base_headers.concat(header_type == :ca ? ca_headers : us_headers)
    end

end