require 'open_chain/report/report_helper'

module OpenChain
  module Report
    class MonthlyEntrySummation
      include OpenChain::Report::ReportHelper

      def self.permission?(user)
        user.entry_view? && user.broker_invoice_view?
      end

      def self.run_report(run_by, settings={})
        self.new.run run_by, settings
      end

      def run(run_by, settings)
        workbook = Spreadsheet::Workbook.new
        sheet = workbook.create_worksheet name: "Entry Summation"
        timezone = ActiveSupport::TimeZone[run_by.time_zone]
        start_date = timezone.parse(settings['start_date']).in_time_zone("UTC")
        end_date = timezone.parse(settings['end_date']).in_time_zone("UTC")
        timezone_id = timezone.tzinfo.identifier
        cust_no = settings['customer_number']

        query = entry_summation_query(start_date, end_date, settings['customer_number'], timezone_id)

        data_conversions = {}
        data_conversions[5] = lambda do |result_set_row, raw_column_value|
          monthly_charge_sum(result_set_row[0], timezone, cust_no, ["'F'"])
        end
        data_conversions[6] = lambda do |result_set_row, raw_column_value|
          monthly_charge_sum(result_set_row[0], timezone, cust_no, ["'F'", "'D'"], true)
        end

        table_from_query sheet, query, data_conversions
        workbook_to_tempfile workbook, 'MonthlyEntrySummation-'
      end

      def entry_summation_query(start_date, end_date, customer_number, timezone)
        q = <<QRY
SELECT
  DATE_FORMAT(convert_tz(entries.release_date, 'UTC', ?),'%Y-%m') AS `Year / Month`,
  (SELECT COUNT(DISTINCT container_number) FROM containers JOIN entries AS entry ON entry_id = entry.id WHERE DATE_FORMAT(convert_tz(entry.release_date, 'UTC', ?),'%Y-%m') = `Year / Month` AND entry.customer_number = ?) AS `Total Containers`,
  SUM(entries.total_invoiced_value) AS `Total Invoice Value`,
  SUM(entries.total_duty + entries.total_duty_direct) AS `Total Duty`,
  SUM(entries.total_fees) AS `Total Fees`,
  '' AS `Total Freight`,
  '' AS `Total Brokerage Fees`
FROM entries
WHERE entries.release_date >= ? AND entries.release_date < ?
  AND entries.customer_number = ?
GROUP BY `Year / Month`
QRY
        ActiveRecord::Base.sanitize_sql_array([q, timezone, timezone, customer_number, start_date, end_date, customer_number])
      end

      def monthly_charge_sum year_month, timezone, customer_number, charge_types, not_in = false
        first_of_month = timezone.parse("#{year_month}-01")
        end_of_month = first_of_month + 1.month
        qry = <<QRY
SELECT SUM(charge_amount)
FROM broker_invoices
INNER JOIN broker_invoice_lines ON broker_invoice_id = broker_invoices.id
INNER JOIN entries ON broker_invoices.entry_id = entries.id
WHERE entries.release_date >= ? AND entries.release_date < ? AND entries.customer_number = ?
AND broker_invoice_lines.charge_type #{not_in ? "NOT IN" : "IN"} (?)
AND broker_invoices.invoice_date >= ? AND broker_invoices.invoice_date < ? AND broker_invoices.customer_number = ?
QRY
        qry = ActiveRecord::Base.sanitize_sql_array([qry, first_of_month.in_time_zone("UTC"), end_of_month.in_time_zone("UTC"), customer_number, charge_types, first_of_month.strftime("%Y-%m-%d"), end_of_month.strftime("%Y-%m-%d"), customer_number])
        r_val = BigDecimal("0")
        execute_query(qry) do |result_set|
          val = result_set.try(:first).try(:first)
          r_val = val unless val.nil?
        end
        r_val
      end

    end
  end
end
