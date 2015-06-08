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
        table_from_query sheet, entry_summation_query(settings[:start_date], settings[:end_date])
        workbook_to_tempfile workbook, 'MonthlyEntrySummation-'
      end

      def entry_summation_query(start_date, end_date)
        q = <<QRY
SELECT
  DATE_FORMAT(entries.release_date,'%Y-%m') AS `Year / Month`,
  (SELECT COUNT(DISTINCT container_number) FROM containers JOIN entries AS entry ON entry_id = entry.id WHERE DATE_FORMAT(entry.release_date,'%Y-%m') = `Year / Month`) AS `Total Containers`,
  SUM(entries.total_invoiced_value) AS `Total Invoice Value`,
  SUM(entries.total_duty + entries.total_duty_direct) AS `Total Duty`,
  SUM(entries.total_fees) AS `Total Fees`,
  (SELECT SUM(charge_amount) FROM broker_invoices JOIN broker_invoice_lines ON broker_invoice_id = broker_invoices.id WHERE charge_type <> 'F' AND broker_invoices.entry_id = entries.id ) AS `Total Freight`,
  (SELECT SUM(charge_amount) FROM broker_invoices JOIN broker_invoice_lines ON broker_invoice_id = broker_invoices.id WHERE charge_type NOT IN ('F','D') AND broker_invoices.entry_id = entries.id) AS `Total Brokerage Fees`
FROM entries
WHERE entries.release_date BETWEEN #{start_date} AND #{end_date}
GROUP BY `Year / Month`
QRY
        q
      end

    end
  end
end