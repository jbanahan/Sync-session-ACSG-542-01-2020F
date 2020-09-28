require 'open_chain/report/builder_output_report_helper'

module OpenChain; module Report; class AscenaFtzMonthlyBrokerInvoiceReport
  include OpenChain::Report::BuilderOutputReportHelper

  attr_reader :customer_number

  class Wrapper < RowWrapper
    FIELD_MAP ||= {id: 0, company_code: 1, vendor_number: 2, invoice_date: 3, posting_date: 4, invoice_number: 5, invoice_total: 6, currency: 7,
                   tax_amount: 8, item_text: 9, baseline_date: 10, partner_bank: 11, assignment_number: 12, invoice_number_2: 13, general_ledger_account: 14,
                   debit_credit: 15, amount: 16, sales_tax_code: 17, item_text_2: 18, cost_center: 19, profit_center: 20, blank_field: 21 }.freeze

    def initialize row
      super row, FIELD_MAP
    end
  end

  IMPORTER_INFO ||= {"ASCE" => ["Ascena", "ATS"], "MAUR" => ["Maurices", "MAU"]}.freeze

  def self.run_schedulable settings = {}
    self.new(settings['customer_number']).send_email settings['email'], settings['cc']
  end

  def initialize cust_num
    @customer_number = cust_num
  end

  def importer
    imp = Company.with_identifier(["Customs Management"], customer_number).first
    raise "Importer not found!" unless imp
    imp
  end

  def column_names
    ["ID Column", "Company Code", "Vendor Number", "Invoice Date in Document", "Posting Date in Document",
     "Invoice Number", "Invoice Total Amount", "Currency Key", "Tax Amount", "Item Text (Description)", "Baseline Date",
     "Partner Bank Type", "Assignment Number", "Invoice Number", "General Ledger Account", "Debit/Credit Indicator",
     "Amount in Document Currency", "Sales Tax Code", "Item Text", "Cost Center", "Profit Center", "BLANK FIELD"]
  end

  def column_styles
    [nil, nil, nil, :date, :date, nil, :default_currency, nil, nil, nil, :date, nil, nil, nil, nil, nil, :default_currency, nil, nil, nil, nil, nil]
  end

  def imp_name
    IMPORTER_INFO[customer_number][0]
  end

  def imp_prefix
    IMPORTER_INFO[customer_number][1]
  end

  def send_email to_addr, cc_addr
    start_date = (ActiveSupport::TimeZone["Eastern Time (US & Canada)"].now - 1.month).beginning_of_month
    title = "#{imp_name} Monthly FTZ Broker Invoice Report - #{start_date.strftime('%m-%Y')}"
    wb = create_workbook start_date
    write_builder_to_tempfile(wb, title) do |t|
      wb.write t
      t.flush
      OpenMailer.send_simple_html(to_addr, title, %(Attached is the completed report named "#{title}.xls").html_safe, t, cc: cc_addr).deliver_now # rubocop:disable Rails/OutputSafety
    end
  end

  def create_workbook start_date
    builder = XlsxBuilder.new
    invoices = broker_invoice_data(start_date)
    invoice_summary = summarize_invoices(invoices)
    write_detail_tab builder, invoices, start_date
    invoice_total = invoice_summary.values.map { |v| v[:total] }.sum
    write_summary_tab builder, invoice_total, start_date
    write_internal_tab builder, invoice_summary
    builder
  end

  def write_detail_tab builder, invoice_data, start_date
    detail = builder.create_sheet "#{start_date.strftime('%m-%Y')} Detail"
    unwrapped_invoices = Wrapper.unwrap_all invoice_data
    builder.create_style(:date, {format_code: "MM-DD-YY"}, prevent_override: false, return_existing: true)
    write_result_set_to_builder builder, detail, unwrapped_invoices
  end

  def write_summary_tab builder, total, start_date
    summary = builder.create_sheet "#{start_date.strftime('%m-%Y')} Summary"
    write_header_row builder, summary, ["Vendor Number", "Invoice Date", "Invoice Number", "Invoice Total", "IOR"]
    row = ["77519", Time.zone.now.to_date, "#{imp_prefix}-FTZ#{Time.zone.now.strftime('%m%Y')}", total, imp_prefix]
    builder.create_style(:summary_date, {format_code: "M/D/YYYY"}, prevent_override: false, return_existing: true)
    write_body_row builder, summary, row, styles: [nil, :summary_date, nil, :default_currency, nil]
  end

  def write_internal_tab builder, totals
    internal = builder.create_sheet "VFI - Internal Use Only"
    write_header_row builder, internal, ["Broker Invoice Date", "Invoice Number", "Invoice Total Amount"]
    totals.keys.sort.each do |inv_num|
      row = [totals[inv_num][:date], inv_num, totals[inv_num][:total]]
      write_body_row builder, internal, row, styles: [:default_date, nil, :default_currency]
    end
  end

  def date_lambda
    ->(_result_set_row, raw_column_value) { raw_column_value.strftime('%m-%d-%y') }
  end

  def string_lambda
    ->(_result_set_row, raw_column_value) { raw_column_value.to_s }
  end

  def summarize_invoices invoice_rows
    totals = Hash.new { |h, k| h[k] = {total: BigDecimal("0"), date: nil} }
    invoice_rows.each do |row|
      next unless row[:id] == "H"
      inv_num = row[:invoice_number]
      indicator = row[:debit_credit]
      amount = row[:invoice_total]
      totals[inv_num][:total] += (indicator == "S" ? amount : -1 * amount)
      totals[inv_num][:date] = row[:invoice_date]
    end
    totals
  end

  def broker_invoice_data start_date
    end_date = start_date.end_of_month
    invoices = []
    execute_query query(importer.id, start_date.strftime('%Y-%m-%d'), end_date.strftime('%Y-%m-%d')) do |result_set|
      if result_set.count > 0
        wrapped_results = Wrapper.wrap_all result_set
        invoices = compile_invoices(wrapped_results)
      end
    end
    invoices
  end

  def compile_invoices results
    raw_lines = []
    inv_lines = []
    inv_number = results.first[:invoice_number]
    results.each do |r|
      if r[:invoice_number] == inv_number
        raw_lines << r
      else
        inv_lines.concat(arrange_rows(raw_lines))
        raw_lines = [r]
        inv_number = r[:invoice_number]
      end
    end
    inv_lines.concat(arrange_rows(raw_lines))
  end

  def arrange_rows rows
    rows.sort! { |a, b| by_description a, b }
    arranged = []
    add_header rows.first, arranged
    add_details rows.drop(1), arranged
    arranged
  end

  def add_header row, collection
    row[:id] = "H"
    collection << row
  end

  def add_details rows, collection
    rows.each do |r|
      r[:id] = "D"
      r[:invoice_total] = ""
      collection << r
    end
  end

  def by_description a, b
    if a[:item_text].upcase == "CUSTOMS ENTRY"
      -1
    elsif b[:item_text].upcase == "CUSTOMS ENTRY"
      1
    else
      a[:item_text].upcase <=> b[:item_text].upcase
    end
  end

  def query importer_id, start_date, end_date
    <<-SQL
      SELECT "" AS "ID Column",
             "" AS "Company Code",
             "77519" AS "Vendor Number",
             bi.invoice_date AS "Invoice Date in Document",
             "" AS "Posting Date in Document",
             bi.invoice_number AS "Invoice Number",
             Abs(bi.invoice_total) AS "Invoice Total Amount",
             "USD" AS "Currency Key",
             "" AS "Tax Amount",
             bil.charge_description AS "Item Text (Description)",
             bi.invoice_date AS "Baseline Date",
             "USD1" AS "Partner Bank Type",
             "" AS "Assignment Number",
             bi.invoice_number AS "Invoice Number",
             "" AS "General Ledger Account",
             (IF(bil.charge_amount >= 0, "S", "H")) AS 'Debit/Credit Indicator',
             Abs(bil.charge_amount) AS "Amount in Document Currency",
             "U1" AS "Sales Tax Code",
             bil.charge_description AS "Item Text",
             "" AS "Cost Center",
             "" AS "Profit Center",
             "" AS "BLANK FIELD"
      FROM entries e
        INNER JOIN broker_invoices bi ON e.id = bi.entry_id
        INNER JOIN broker_invoice_lines bil ON bi.id = bil.broker_invoice_id
        LEFT OUTER JOIN (SELECT e2.id, CHAR_LENGTH(GROUP_CONCAT(cil.po_number SEPARATOR "")) > 0 AS has_po_numbers
                         FROM entries e2
                           INNER JOIN broker_invoices bi2 ON e2.id = bi2.entry_id
                           LEFT OUTER JOIN commercial_invoices ci ON e2.id = ci.entry_id
                           LEFT OUTER JOIN commercial_invoice_lines cil ON ci.id = cil.commercial_invoice_id
                         WHERE e2.importer_id = #{importer_id}
                           AND e2.entry_type = "01"
                           AND bi2.invoice_date BETWEEN '#{start_date}' AND '#{end_date}'
                         GROUP BY e2.id
                         HAVING has_po_numbers = true) AS entries_with_po ON e.id = entries_with_po.id
      WHERE e.importer_id = #{importer_id}
        AND (e.first_entry_sent_date IS NOT NULL OR bil.charge_code = "0191")
        AND (e.entry_type = "06" OR (e.entry_type = "01" AND entries_with_po.id IS NULL))
        AND (bi.invoice_date BETWEEN '#{start_date}' AND '#{end_date}')
        AND (bil.charge_type <> 'D' OR bil.charge_type IS NULL)
      ORDER BY bi.invoice_number
    SQL
  end

end; end; end
