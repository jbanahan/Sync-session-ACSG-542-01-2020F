require 'open_chain/report/report_helper'
module OpenChain
  module Report
    class EddieBauerCaK84Summary
      include OpenChain::Report::ReportHelper

      def self.permission? user
        MasterSetup.get.system_code=='www-vfitrack-net' && user.company.master? && user.view_commercial_invoices? 
      end

      def run(user, settings)
        wb = XlsMaker.create_workbook "CA K84 Summary - Eddie Bauer"
        XlsMaker.create_sheet wb, "CA K84 Detail - Eddie Bauer"
        XlsMaker.create_sheet wb, "CA K84 Summary - EB Supply"
        XlsMaker.create_sheet wb, "CA K84 Detail - EB Supply"
        XlsMaker.create_sheet wb, "CA K84 Summary - Eddie LLC"
        XlsMaker.create_sheet wb, "CA K84 Detail - Eddie LLC"
        XlsMaker.create_sheet wb, "CA K84 Summary - Eddie eCommerce"
        XlsMaker.create_sheet wb, "CA K84 Detail - Eddie eCommerce"
        
        fill_sheets(user, wb, settings['date'], 0, 1, "EDDIEBR")
        fill_sheets(user, wb, settings['date'], 2, 3, "EBSUPPLY")
        fill_sheets(user, wb, settings['date'], 4, 5, "EDDIE")
        fill_sheets(user, wb, settings['date'], 6, 7, "EBECOMM")
        
        workbook_to_tempfile wb, 'EddieBauerCaK84-'
      end

      def fill_sheets(user, workbook, date, summary_sheet_no, detail_sheet_no, customer_number)
        table_from_query workbook.worksheet(summary_sheet_no), po_query(user, customer_number, date), 
          {2 => currency_format_lambda, 3 => currency_format_lambda, 4 => currency_format_lambda, 7 => currency_format_lambda, 8 => currency_format_lambda, 9 => currency_format_lambda} 
        table_from_query workbook.worksheet(detail_sheet_no), detail_query(user, customer_number, date), 
          {5 => currency_format_lambda, 6 => currency_format_lambda, 7 => currency_format_lambda, 8 => currency_format_lambda, 9 => currency_format_lambda, 11 => weblink_translation_lambda(CoreModule::ENTRY)}
      end

      def currency_format_lambda
        lambda { |result_set_row, raw_column_value| sprintf('%.2f', raw_column_value) if raw_column_value }
      end

      def po_query(user, customer_number, date)
        <<-SQL
          SELECT (CASE SUBSTR(cil.po_number, 1, 1) WHEN "E" THEN "NON-MERCH" ELSE "MERCH" END) AS Business,
                 cil.po_number AS "Invoice Line - PO number",
                 SUM(cit.duty_amount) AS Duty,
                 SUM(cit.gst_amount + cit.sima_amount) AS Fees,
                 SUM(cit.duty_amount + cit.gst_amount + cit.sima_amount) AS "Total Duty/Fee",
                 e.release_date AS "Date Cleared",
                 e.master_bills_of_lading AS "BOL #",
                 SUM(cit.entered_value) AS "Entered Value",
                 SUM(cit.entered_value) * 0.18 AS "Avg Duty 18%",
                 SUM(cit.duty_amount) - (SUM(cit.entered_value) * 0.18) AS "+/- Duty"
          FROM entries AS e
            INNER JOIN commercial_invoices AS ci ON e.id = ci.entry_id
            INNER JOIN commercial_invoice_lines AS cil ON ci.id = cil.commercial_invoice_id
            INNER JOIN commercial_invoice_tariffs AS cit ON cil.id = cit.commercial_invoice_line_id
          WHERE e.customer_number = "#{customer_number}"
            AND e.k84_due_date = "#{date}"
            AND e.entry_type != "F"
          GROUP BY cil.po_number, e.release_date, e.master_bills_of_lading
          ORDER BY e.release_date, cil.po_number
        SQL
      end

      def detail_query(user, customer_number, date)
        <<-SQL
          SELECT e.broker_reference AS "Broker Reference",
                 e.release_date AS "Release Date",
                 e.cadex_sent_date AS "CADEX Sent Date",
                 cil.po_number AS "Invoice Line - PO Number",
                 (CASE SUBSTR(cil.po_number, 1, 1) WHEN "E" THEN "NON-MERCH" ELSE "MERCH" END) AS Business,
                 SUM(cit.entered_value) AS "Invoice Tariff - Entered Value",
                 SUM(cit.duty_amount) AS "Invoice Tariff - Duty",
                 SUM(cit.gst_amount + cit.sima_amount) AS "Invoice Tariff - Fees",
                 SUM(cit.gst_amount + cit.sima_amount + cit.duty_amount) AS "Due Crown",
                 SUM(cit.duty_amount) / SUM(cit.entered_value) AS "Calculated Duty %",
                 cil.line_number AS "Invoice Line - Line Number",
                 e.id AS "Web Links"
          FROM entries AS e
            INNER JOIN commercial_invoices AS ci ON e.id = ci.entry_id
            INNER JOIN commercial_invoice_lines AS cil ON ci.id = cil.commercial_invoice_id
            INNER JOIN commercial_invoice_tariffs AS cit ON cil.id = cit.commercial_invoice_line_id
          WHERE e.customer_number = "#{customer_number}"
            AND e.k84_due_date = "#{date}"
            AND e.entry_type != "F"
          GROUP BY cil.po_number, cil.line_number, e.broker_reference, e.release_date, e.cadex_sent_date
          ORDER BY e.release_date, e.broker_reference, cil.line_number
        SQL
      end

      def self.run_report(user, settings = {})
        self.new.run(user, settings)
      end
    
    end
  end
end