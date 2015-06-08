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

        start_date = settings['start_date'].to_datetime.midnight
        end_date = settings['end_date'].to_datetime.midnight - 1.second
        timezone = ActiveSupport::TimeZone[run_by.time_zone].tzinfo.identifier

        table_from_query sheet, entry_summation_query(start_date, end_date, settings['customer_number'], timezone)
        workbook_to_tempfile workbook, 'MonthlyEntrySummation-'
      end

      def entry_summation_query(start_date, end_date, customer_number, timezone)
        q = <<QRY
SELECT
  DATE_FORMAT(convert_tz(entries.release_date, 'UTC', '#{timezone}'),'%Y-%m') AS `Year / Month`,
  (SELECT COUNT(DISTINCT container_number) FROM containers JOIN entries AS entry ON entry_id = entry.id WHERE DATE_FORMAT(convert_tz(entry.release_date, 'UTC', '#{timezone}'),'%Y-%m') = `Year / Month`) AS `Total Containers`,
  SUM(entries.total_invoiced_value) AS `Total Invoice Value`,
  SUM(entries.total_duty + entries.total_duty_direct) AS `Total Duty`,
  SUM(entries.total_fees) AS `Total Fees`,
  (SELECT SUM(charge_amount) FROM broker_invoices JOIN broker_invoice_lines ON broker_invoice_id = broker_invoices.id JOIN entries AS entry ON broker_invoices.entry_id = entry.id WHERE DATE_FORMAT(convert_tz(entry.release_date, 'UTC', '#{timezone}'),'%Y-%m') = `Year / Month` AND charge_type = 'F' ) AS `Total Freight`,
  (SELECT SUM(charge_amount) FROM broker_invoices JOIN broker_invoice_lines ON broker_invoice_id = broker_invoices.id JOIN entries AS entry ON broker_invoices.entry_id = entry.id WHERE DATE_FORMAT(convert_tz(entry.release_date, 'UTC', '#{timezone}'),'%Y-%m') = `Year / Month` AND charge_type NOT IN ('F','D')) AS `Total Brokerage Fees`
FROM entries
WHERE convert_tz(entries.release_date, 'UTC', '#{timezone}') BETWEEN '#{start_date}' AND '#{end_date}'
  AND entries.customer_number = '#{customer_number}'
GROUP BY `Year / Month`
QRY
        q
      end

    end
  end
end