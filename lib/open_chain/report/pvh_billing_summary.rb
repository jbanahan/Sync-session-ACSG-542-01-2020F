require 'open_chain/report/report_helper'
module OpenChain
  module Report
    class PvhBillingSummary
      include OpenChain::Report::ReportHelper

      def self.permission? user
        user.view_broker_invoices? && user.company.master? && MasterSetup.get.system_code=='www-vfitrack-net'
      end

      def self.run_report(user, settings = {})
        settings = settings.with_indifferent_access
        self.new.run(settings)
      end

      def run(settings)
        wb = create_workbook(settings[:invoice_numbers])
        workbook_to_tempfile wb, 'PvhBillingSummary-'
      end
      
      def create_workbook(invoice_numbers)        
        wb = XlsMaker.create_workbook 'LVS Billing'
        XlsMaker.create_sheet wb, 'HVS Billing'
        lvs = combined_query(:lvs, invoice_numbers)
        hvs = combined_query(:hvs, invoice_numbers)

        table_from_query_result wb.worksheet(0), lvs[:results], {}, {column_names: lvs[:header]}
        table_from_query_result wb.worksheet(1), hvs[:results], {}, {column_names: hvs[:header]}

        wb
      end

      def combined_query(report_type, invoice_numbers)
        brokerage_duty_qry = ActiveRecord::Base.connection.execute query(report_type, true, invoice_numbers)
        column_names = brokerage_duty_qry.fields[0..-1]
        fees_query = ActiveRecord::Base.connection.execute query(report_type, false, invoice_numbers)

        combined = []
        brokerage_duty_qry.each do |outer_line|
          combined << outer_line
          matching = fees_query.find{ |inner_line| inner_line[5] == outer_line[5] }
          combined << matching if matching
        end
        {header: column_names, results: combined}
      end

      def query(report_type, brokerage_duty, invoice_numbers)
        type = "LV" if report_type == :lvs
        type = "AB" if report_type == :hvs

        <<-SQL
          SELECT '' AS 'BATCH',
            '' AS 'CO',
            '' AS 'PROCESS LEVEL',
            '7171103' AS 'VENDOR',
            'VANDEGRIFT CANADA ULC' AS 'VENDOR NAME',
            bi.invoice_number AS 'INVOICE',
            bi.invoice_date AS 'INVOICE DATE',
            '' AS 'DUE DATE',
            bi.invoice_total AS 'INVOICE AMOUNT',
            '' AS 'FC',
            '' AS 'COMPANY',
            '' AS 'ACCT',
            '' AS 'ACCT',
            '' AS 'ACCT',
            SUM(bil.charge_amount) AS 'INVOICE AMOUNT',
            '' AS 'ENCLOSURE',
            '' AS 'SEPARATE STATEMENT',
            '' AS 'DESCRIPTION',
            '' AS 'REMIT CODE',
            '' AS 'INVOICE TYPE'
          FROM entries AS e 
            INNER JOIN broker_invoices AS bi ON e.id = bi.entry_id
            INNER JOIN broker_invoice_lines AS bil ON bi.id = bil.broker_invoice_id
          WHERE bi.invoice_number IN (#{invoice_numbers.join(',')}) AND
                bil.charge_code#{brokerage_duty ? "" : " NOT" } IN (1, 22) AND
                e.entry_type = '#{type}'
          GROUP BY bi.id
          ORDER BY bi.invoice_number;
        SQL
      end
    
    end
  end
end