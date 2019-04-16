require 'open_chain/report/builder_output_report_helper'
module OpenChain
  module Report
    class EddieBauerCaK84Summary
      include OpenChain::Report::BuilderOutputReportHelper

      def self.permission? user
        MasterSetup.get.custom_feature?("WWW VFI Track Reports") && user.company.master? && user.view_entries?
      end

      def run(user, settings)
        wb = XlsxBuilder.new
        eddiebrs = wb.create_sheet "CA K84 Summary - Eddie Bauer"
        eddiebrd = wb.create_sheet "CA K84 Detail - Eddie Bauer"
        ebsupplys = wb.create_sheet "CA K84 Summary - EB Supply"
        ebsupplyd = wb.create_sheet "CA K84 Detail - EB Supply"
        eddies = wb.create_sheet "CA K84 Summary - Eddie LLC"
        eddied = wb.create_sheet "CA K84 Detail - Eddie LLC"
        ebecomms = wb.create_sheet "CA K84 Summary - Eddie eComm"
        ebecommd = wb.create_sheet "CA K84 Detail - Eddie eCommerce"
        
        fill_sheets(user, wb, settings['date'], eddiebrs, eddiebrd, "EDDIEBR")
        fill_sheets(user, wb, settings['date'], ebsupplys, ebsupplyd, "EBSUPPLY")
        fill_sheets(user, wb, settings['date'], eddies, eddied, "EDDIE")
        fill_sheets(user, wb, settings['date'], ebecomms, ebecommd, "EBECOMM")
        
        write_builder_to_tempfile wb, "EddieBauerCaK84-"
      end

      def fill_sheets(user, workbook, date, summary_sheet, detail_sheet, customer_number)
        safe_date = sanitize_date_string date
        write_query_to_builder workbook, summary_sheet, po_query(user, customer_number, safe_date), 
          data_conversions: {"Duty" => currency_format_lambda, "Fees" => currency_format_lambda, "SIMA and Excise" => currency_format_lambda, "Total Duty/Fee" => currency_format_lambda, "Entered Value" => currency_format_lambda, "Avg Duty 18%" => currency_format_lambda, "+/- Duty" => currency_format_lambda} 
        write_query_to_builder workbook, detail_sheet, detail_query(user, customer_number, safe_date), 
          data_conversions: {"Invoice Tariff - Entered Value" => currency_format_lambda, "Invoice Tariff - Duty" => currency_format_lambda, "Invoice Tariff - Fees" => currency_format_lambda, "Invoice Tariff - SIMA" => currency_format_lambda, "Invoice Tariff - Excise" => currency_format_lambda, "Due Crown" => currency_format_lambda, "Web Links" => weblink_translation_lambda(workbook, Entry)}
      end

      def currency_format_lambda
        lambda { |result_set_row, raw_column_value| sprintf('%.2f', raw_column_value) if raw_column_value }
      end

      def po_query(user, customer_number, date)
        <<-SQL
          SELECT (CASE SUBSTR(cil.po_number, 1, 1) WHEN "E" THEN "NON-MERCH" ELSE "MERCH" END) AS Business,
                 cil.po_number AS "Invoice Line - PO number",
                 SUM(cit.duty_amount) AS Duty,
                 SUM(cit.gst_amount) AS Fees,
                 SUM(cit.sima_amount + cit.excise_amount) AS "SIMA and Excise",
                 SUM(cit.duty_amount + cit.gst_amount + cit.sima_amount + cit.excise_amount) AS "Total Duty/Fee",
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
                 SUM(cit.gst_amount) AS "Invoice Tariff - Fees",
                 SUM(cit.sima_amount) AS "Invoice Tariff - SIMA",
                 SUM(cit.excise_amount) AS "Invoice Tariff - Excise",
                 SUM(cit.gst_amount + cit.sima_amount + cit.duty_amount + cit.excise_amount) AS "Due Crown",
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
