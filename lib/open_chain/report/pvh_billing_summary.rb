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
        wb, lvs_sheet = XlsMaker.create_workbook_and_sheet 'LVS Billing', numeric_headers
        hvs_sheet = XlsMaker.create_sheet wb, 'HVS Billing', numeric_headers
        v_sheet = XlsMaker.create_sheet wb, 'V Billing', numeric_headers
        lvs = combined_query(:lvs, invoice_numbers)
        hvs = combined_query(:hvs, invoice_numbers)
        v = combined_query(:v, invoice_numbers)

        table_from_query_result lvs_sheet, lvs[:results], {}, {column_names: lvs[:header], header_row: 1}
        table_from_query_result hvs_sheet, hvs[:results], {}, {column_names: hvs[:header], header_row: 1}
        table_from_query_result v_sheet, v[:results], {}, {column_names: v[:header], header_row: 1}

        wb
      end

      def numeric_headers 
        ['F17', 'F8', 'F11', 'F24', '', 'F29', 'F32', 'F35', 'F38', 'F164', 'F165', 'F166', 'F167', 'F168', 'F173', 'F104', 'F102', 'F127', 'F28', 'F36']
      end

      def combined_query(report_type, invoice_numbers)
        column_names = []
        combined = []
        execute_query(query(report_type, true, invoice_numbers)) do |brokerage_duty_qry|
          column_names = brokerage_duty_qry.fields[0..-1]
          execute_query(query(report_type, false, invoice_numbers)) do |fees_query|
            brokerage_duty_qry.each do |outer_line|
              combined << outer_line
              matching = fees_query.find{ |inner_line| inner_line[5] == outer_line[5] }
              combined << matching if matching
            end
          end
        end
        {header: column_names, results: combined}
      end

      def query(report_type, brokerage_duty, invoice_numbers)
        type = "LV" if report_type == :lvs
        type = "AB" if report_type == :hvs
        type = "V" if report_type == :v
        safe_invoice_numbers = invoice_numbers.map{ |inv| ActiveRecord::Base.sanitize inv }.join(',')

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
          WHERE bi.invoice_number IN (#{safe_invoice_numbers}) AND
                bil.charge_code#{brokerage_duty ? "" : " NOT" } IN (1, 22) AND
                e.entry_type = '#{type}'
          GROUP BY bi.id
          ORDER BY bi.invoice_number;
        SQL
      end
    
    end
  end
end