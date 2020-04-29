require 'open_chain/report/report_helper'

module OpenChain; module Report; class AnnMonthlyBrokerInvoiceReport
  include OpenChain::Report::ReportHelper

  SYSTEM_CODE = "ATAYLOR"

  ROW_MAP = {id: 0, company_code: 1, vendor_number: 2, invoice_date: 3, posting_date: 4, invoice_number: 5, invoice_total: 6, currency: 7,
             tax_amount: 8, item_text: 9, baseline_date: 10, partner_bank: 11, assignment_number: 12, invoice_number_2: 13, general_ledger_account: 14,
             debit_credit: 15, amount: 16, sales_tax_code: 17, item_text_2: 18, cost_center: 19, profit_center: 20, blank_field: 21 }

  HEADER = ["ID Column", "Company Code", "Vendor Number", "Invoice Date in Document", "Posting Date in Document",
            "Invoice Number", "Invoice Total Amount", "Currency Key", "Tax Amount", "Item Text (Description)", "Baseline Date",
            "Partner Bank Type", "Assignment Number", "Invoice Number", "General Ledger Account", "Debit/Credit Indicator",
            "Amount in Document Currency", "Sales Tax Code", "Item Text", "Cost Center", "Profit Center", "BLANK FIELD"]

  def self.importer
    imp = Company.where(system_code: SYSTEM_CODE).first
    raise "Importer not found!" unless imp
    imp
  end

  def self.run_schedulable settings={}
    self.new.send_email settings['email'], settings['cc']
  end

  def send_email to_addr, cc_addr
    start_date = (ActiveSupport::TimeZone["Eastern Time (US & Canada)"].now - 1.month).beginning_of_month
    title = "Ann Inc. Monthly Broker Invoice Report – #{start_date.strftime('%m-%Y')}"
    wb = create_workbook start_date
    workbook_to_tempfile(wb, "report", file_name: "#{title}.xls") do |t|
      wb.write t
      t.flush
      OpenMailer.send_simple_html(to_addr, title, %Q(Attached is the completed report named "#{title}.xls").html_safe, t, cc: cc_addr).deliver_now
    end
  end

  def create_workbook start_date
    wb, sheet = XlsMaker.create_workbook_and_sheet(start_date.strftime('%m-%Y'))
    table_from_query_result sheet, get_invoices(start_date), {"Invoice Date in Document"=>dt_lambda, "Baseline Date"=>dt_lambda, "Assignment Number"=>assignment_number_lambda }, {column_names: HEADER}
    wb
  end

  def dt_lambda
    lambda { |result_set_row, raw_column_value| DateTime.parse(raw_column_value).in_time_zone("Eastern Time (US & Canada)").strftime('%m-%d-%y')}
  end

  def assignment_number_lambda
    lambda { |result_set_row, raw_column_value| raw_column_value.split("\n ").first }
  end

  def get_invoices start_date
    end_date = start_date.end_of_month
    invoices = []
    execute_query query(self.class.importer.id, start_date.strftime('%Y-%m-%d'), end_date.strftime('%Y-%m-%d')) do |result_set|
      invoices = compile_invoices(result_set) unless result_set.count == 0
    end
    invoices
  end

  def compile_invoices results
    raw_lines =  []; inv_lines = []
    inv_number = results.first[ROW_MAP[:invoice_number]]
    results.each do |r|
      if r[ROW_MAP[:invoice_number]] == inv_number
        raw_lines << r.map(&:to_s)
      else
        inv_lines.concat(arrange_rows raw_lines)
        raw_lines = [r.map(&:to_s)]
        inv_number = r[ROW_MAP[:invoice_number]]
      end
    end
    inv_lines.concat(arrange_rows raw_lines)
  end

  def arrange_rows rows
    rows.sort! { |a, b| by_description a, b }
    arranged = []
    add_header rows.first, arranged
    add_details rows.drop(1), arranged
    arranged
  end

  def add_header row, collection
    row[ROW_MAP[:id]] = "H"
    collection << row
  end

  def add_details rows, collection
    rows.each do |r|
      r[ROW_MAP[:id]] = "D"
      r[ROW_MAP[:invoice_total]] = ""
      collection << r
    end
  end

  def by_description a, b
    if a[ROW_MAP[:item_text]].upcase == "CUSTOMS ENTRY"
      -1
    elsif b[ROW_MAP[:item_text]].upcase == "CUSTOMS ENTRY"
      1
    else
      a[ROW_MAP[:item_text]].upcase <=> b[ROW_MAP[:item_text]].upcase
    end
  end

  def query importer_id, start_date, end_date
    <<-SQL
      SELECT "" AS "ID Column",
             "1100" AS "Company Code",
             "1003709" AS "Vendor Number",
             bi.invoice_date AS "Invoice Date in Document",
             "" AS "Posting Date in Document",
             bi.invoice_number AS "Invoice Number",
             Abs(bi.invoice_total) AS "Invoice Total Amount",
             "USD" AS "Currency Key",
             "" AS "Tax Amount",
             bil.charge_description AS "Item Text (Description)",
             bi.invoice_date AS "Baseline Date",
             "USD1" AS "Partner Bank Type",
             e.po_numbers AS "Assignment Number",
             bi.invoice_number AS "Invoice Number",
             "200190" AS "General Ledger Account",
             (IF(bil.charge_amount >= 0, "S", "H")) AS 'Debit/Credit Indicator',
             Abs(bil.charge_amount) AS "Amount in Document Currency",
             "U1" AS "Sales Tax Code",
             bil.charge_description AS "Item Text",
             "" AS "Cost Center",
             "309401" AS "Profit Center",
             "" AS "BLANK FIELD"
      FROM entries e
        INNER JOIN broker_invoices bi ON e.id = bi.entry_id
        INNER JOIN broker_invoice_lines bil ON bi.id = bil.broker_invoice_id
      WHERE e.importer_id = #{importer_id}
            AND (bi.invoice_date BETWEEN '#{start_date}' AND '#{end_date}')
            AND (bil.charge_type <> 'D' OR bil.charge_type IS NULL)
      ORDER BY bi.invoice_number
    SQL
  end

end; end; end;