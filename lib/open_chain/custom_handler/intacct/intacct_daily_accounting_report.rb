require 'open_chain/report/builder_output_report_helper'
require 'open_chain/report/report_email_helper'

module OpenChain; module CustomHandler; module Intacct; class IntacctDailyAccountingReport
  include OpenChain::Report::BuilderOutputReportHelper
  include OpenChain::Report::ReportEmailHelper

  def self.run_schedulable opts = {}
    self.new.run(opts)
  end

  def run opts = {}
    start_date, end_date = date_range(opts)
    email = parse_email_from_opts(opts)

    # The cast here is because the division is stored as a string, but it's actually a numeric.  If we sort by it we'll end up
    # with 1 then 11, then 2...etc.  We want it sorted in order.
    exports = IntacctAllianceExport.where("invoice_date >= ? AND invoice_date <= ?", start_date, end_date)
                                   .where(export_type: IntacctAllianceExport::EXPORT_TYPE_INVOICE)
                                   .order(["cast(division as signed)", :invoice_date, :file_number, :suffix])

    summary_sheet = build_summary_sheet builder
    ar_sheet = build_ar_sheet builder
    ap_sheet = build_ap_sheet builder
    counter = 0
    exports.pluck(:id).each do |export_id|
      export = retrieve_export(export_id)
      next if export.nil?

      counter += 1

      write_summary_row(builder, summary_sheet, export)
      export.intacct_receivables.each do |receivable|
        write_ar_row(builder, ar_sheet, export, receivable)
      end

      export.intacct_payables.each do |payable|
        write_ap_row(builder, ap_sheet, export, payable)
      end
    end

    if start_date == end_date
      date_range_description = start_date.strftime("%m/%d/%Y")
    else
      date_range_description = "#{start_date.strftime("%m/%d/%Y")} - #{end_date.strftime("%m/%d/%Y")}"
    end

    if counter == 0
      add_no_results_message(builder, summary_sheet, date_range_description)
    else
      write_summary_sums(builder, summary_sheet, counter)
    end

    filename = "Daily Accounting Report #{date_range_description}"

    write_builder_to_tempfile(builder, filename.gsub("/", "-")) do |tempfile|
      body = "Attached is the Daily Accounting Report for #{date_range_description}."
      OpenMailer.send_simple_html(email[:to], filename, body, [tempfile], {cc: email[:cc], bcc: email[:bcc]}).deliver_now
    end
    nil
  end

  private

    def date_range opts
      now = Time.zone.now.to_date
      start_date = date_value(opts['start_date'], default_value: (now - 1.day))
      end_date = date_value(opts['end_date'], default_value: start_date)

      [start_date, end_date]
    end

    def retrieve_export export_id
      IntacctAllianceExport.where(id: export_id).includes(intacct_payables: [:intacct_payable_lines], intacct_receivables: [:intacct_receivable_lines]).first
    end

    def date_value value, default_value: nil
      return default_value if value.blank?

      Date.parse(value)
    end

    def build_summary_sheet builder
      builder.create_sheet "Daily Billing Summary", headers: ["Invoice Number", "Division", "Invoice Date", "Customer", "AR Total", "AP Total", "Profit / Loss"]
    end

    def write_summary_row builder, sheet, export
      row = []
      row << "#{export.file_number}#{export.suffix}"
      row << export.division
      row << export.invoice_date
      row << export.customer_number
      row << export.ar_total
      row << export.ap_total
      row << ((export.ar_total.presence || BigDecimal("0")) - (export.ap_total.presence || BigDecimal("0")))

      builder.add_body_row sheet, row
      nil
    end

    def make_sum_formula column, row_count
      row_count > 0 ? "=SUBTOTAL(9, #{column}2:#{column}#{row_count + 1})" : BigDecimal("0")
    end

    def write_summary_sums builder, sheet, row_count
      format = builder.create_style :bold_decimal, {format_code: "#,##0.00", b: true}

      builder.add_body_row sheet, [nil, nil, nil, nil, make_sum_formula("E", row_count), make_sum_formula("F", row_count), make_sum_formula("G", row_count)],
                           styles: [nil, nil, nil, nil, format, format, format]
    end

    def build_ar_sheet builder
      builder.create_sheet "AR Details", headers: ["Invoice Number", "Division", "Invoice Date", "Customer", "Currency", "Vendor",
                                                   "Vendor Reference", "Charge Code", "Charge Description", "Charge Amount"]
    end

    def write_ar_row builder, sheet, export, receivable
      receivable.intacct_receivable_lines.each do |line|
        row = []
        row << receivable.invoice_number
        row << export.division
        row << receivable.invoice_date
        row << receivable.customer_number
        row << receivable.currency
        row << line.vendor_number
        row << line.vendor_reference
        row << line.charge_code
        row << line.charge_description
        row << line.amount

        builder.add_body_row sheet, row
      end
      nil
    end

    def build_ap_sheet builder
      builder.create_sheet "AP Details", headers: ["Invoice Number", "Division", "Invoice Date", "Customer", "Currency", "Vendor",
                                                   "Vendor Reference", "Charge Code", "Charge Description", "Charge Amount"]
    end

    def write_ap_row builder, sheet, export, payable
      payable.intacct_payable_lines.each do |line|
        row = []
        row << payable.bill_number
        row << export.division
        row << payable.bill_date
        row << export.customer_number
        row << payable.currency
        row << payable.vendor_number
        row << payable.vendor_reference
        row << line.charge_code
        row << line.charge_description
        row << line.amount

        builder.add_body_row sheet, row
      end
    end

    def add_no_results_message builder, sheet, date_range_description
      builder.add_body_row sheet, ["No accounting data found for #{date_range_description}."]
    end

    def builder
      @builder ||= XlsxBuilder.new
    end

end; end; end; end