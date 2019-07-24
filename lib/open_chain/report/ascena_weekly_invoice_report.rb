require 'open_chain/report/report_helper'
require 'open_chain/custom_handler/ascena/ascena_billing_invoice_file_generator'

module OpenChain; module Report; class AscenaWeeklyInvoiceReport
  include OpenChain::Report::ReportHelper

  IMP_NAME = {'ASCE' => 'Ascena', 'MAUR' => 'Maurices'}

  def self.run_schedulable settings={}
    self.new.send_email(settings['customer_number'], settings['email'])
  end

  def create_workbook(cust_num, start_dtime, end_dtime)
    wb, sheet = XlsMaker.create_workbook_and_sheet "#{IMP_NAME[cust_num]} Weekly Invoice Report"
    table_from_query sheet, query(cust_num, start_dtime, end_dtime)
    wb
  end

  def send_email cust_num, email
    range = calculate_range
    wb = create_workbook(cust_num, *range)
    workbook_to_tempfile wb, 'AscenaWeeklyInvoiceReport-', file_name: "#{IMP_NAME[cust_num]} Weekly Invoice Report.xls" do |t|
      subject = "#{IMP_NAME[cust_num]} Weekly Invoice Report - #{range[0].strftime('%-m/%-d/%Y')} to #{range[1].strftime('%-m/%-d/%Y')}"
      body = "<p>Report attached.<br>--This is an automated message, please do not reply.<br>This message was generated from VFI Track</p>".html_safe
      OpenMailer.send_simple_html(email, subject, body, t).deliver_now
    end
  end

  def calculate_range
    now = Time.zone.now.in_time_zone("America/New_York").to_date
    last_tuesday = now.prev_week + 1.day
    this_tuesday = now.beginning_of_week + 1.day
    [create_range_string(last_tuesday), create_range_string(this_tuesday)]
  end

  def create_range_string date
    ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse("#{date.to_s(:db)} 10:00").in_time_zone("UTC")
  end

  def query cust_num, start_dtime, end_dtime
    <<-SQL
      SELECT i.broker_reference AS "Broker Reference", i.invoice_number AS "Invoice Number", i.invoice_date AS "Invoice Date", l.charge_description AS "Charge Description", l.charge_amount AS "Charge Amount"
      FROM broker_invoices i
        INNER JOIN entries e ON e.id = i.entry_id
        INNER JOIN sync_records s ON s.syncable_id = i.id AND s.syncable_type = 'BrokerInvoice' AND s.trading_partner IN ('#{OpenChain::CustomHandler::Ascena::AscenaBillingInvoiceFileGenerator::LEGACY_SYNC}', '#{OpenChain::CustomHandler::Ascena::AscenaBillingInvoiceFileGenerator::BROKERAGE_SYNC}')
        INNER JOIN broker_invoice_lines l ON l.broker_invoice_id = i.id
          AND s.sent_at >= '#{start_dtime}' AND s.sent_at < '#{end_dtime}' AND l.charge_code <> '0001'
      WHERE e.customer_number = #{ActiveRecord::Base.sanitize cust_num}
      ORDER BY i.invoice_date, i.invoice_number, l.charge_code
    SQL
  end
end; end; end
