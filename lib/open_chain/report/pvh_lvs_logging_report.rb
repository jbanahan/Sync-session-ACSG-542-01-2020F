require 'open_chain/report/report_helper'
module OpenChain
  module Report
    class PvhLvsLoggingReport
      include OpenChain::Report::ReportHelper

      def self.run_schedulable opts_hash={}
        self.new.send_email('email' => opts_hash['email'])
      end

      def get_local_time
        start_date_time = (ActiveSupport::TimeZone["Eastern Time (US & Canada)"].now - 8.days).beginning_of_day
        end_date_time = (ActiveSupport::TimeZone["Eastern Time (US & Canada)"].now - 2.days).end_of_day
        [start_date_time, end_date_time]
      end

      def formatted_local_time
        start_date_time, end_date_time = get_local_time
        [start_date_time.strftime("%-m-%-d-%y"), end_date_time.strftime("%-m-%-d-%y")]
      end

      def query_time
        start_date_time, end_date_time = get_local_time
        [start_date_time.to_s(:db), end_date_time.to_s(:db)]
      end

      def create_workbook
        start_date_time, end_date_time = query_time
        wb = XlsMaker.create_workbook 'LVS Logging'
        XlsMaker.create_sheet wb, 'HVS Logging'
        table_from_query wb.worksheet(0), query(:lvs, start_date_time, end_date_time), {'Entry Date' => date_conversion_lambda} 
        table_from_query wb.worksheet(1), query(:hvs, start_date_time, end_date_time), {'Entry Date' => date_conversion_lambda} 
        wb
      end

      def date_conversion_lambda
        lambda { |result_set_row, raw_column_value| raw_column_value.in_time_zone("Eastern Time (US & Canada)").to_date if raw_column_value }
      end

      def send_email(settings)
        wb = create_workbook
        
        workbook_to_tempfile wb, 'PVH-' do |t|
          start_date, end_date = formatted_local_time
          subject = "LVS Logging Report for the Period #{start_date} to #{end_date}"
          body = '<p>Report attached.<br>--This is an automated message, please do not reply. <br> This message was generated from VFI Track</p>'.html_safe
          OpenMailer.send_simple_html(settings['email'], subject, body, t).deliver!
        end
      end

      def query(report_type, start_date_time, end_date_time)
        type = "LV" if report_type == :lvs
        type = "AB" if report_type == :hvs

        <<-SQL
          SELECT e.cargo_control_number AS 'Cargo Control Number',
            e.po_numbers AS 'PO #',
            '' AS Division, 
            '' AS CO,
            e.vendor_names AS Vendor,
            e.origin_country_codes AS 'Factory Country',
            e.total_units AS Units,
            e.entry_number AS 'Entry #',
            e.direct_shipment_date AS 'Shipped Date',
            e.entry_filed_date AS 'Entry Date',
            e.entered_value AS 'Entered Value',
            e.total_duty AS 'B3 Duties',
            bi.invoice_number AS 'Broker Invoice',
            broker_fees.charge_amount AS 'Broker Fees',
            gst_ab.charge_amount AS 'GST (AB)',
            gst_mb.charge_amount AS 'GST (MB)',
            gst_pq.charge_amount AS 'GST (PQ)',
            e.total_gst AS 'GST On Imports',
            hst_on.charge_amount AS 'HST (ON)',
            hst_bc.charge_amount AS 'HST (BC)',
            'Canada' AS 'Country of Final Destination',
            (SELECT GROUP_CONCAT(cit.tariff_description SEPARATOR '; ')
             FROM commercial_invoices AS ci INNER JOIN commercial_invoice_lines AS cil ON ci.id = cil.commercial_invoice_id
             INNER JOIN commercial_invoice_tariffs as cit ON cil.id = cit.commercial_invoice_line_id
             WHERE ci.entry_id = e.id) AS "Description",
            '' AS Contact,
            '' AS 'Bill Code',
            '' AS Paid
          FROM entries AS e 
            INNER JOIN broker_invoices AS bi ON e.id = bi.entry_id
            LEFT OUTER JOIN broker_invoice_lines gst_ab ON gst_ab.broker_invoice_id = bi.id AND gst_ab.charge_code = '251'
            LEFT OUTER JOIN broker_invoice_lines gst_mb ON gst_mb.broker_invoice_id = bi.id AND gst_mb.charge_code = '254'
            LEFT OUTER JOIN broker_invoice_lines gst_pq ON gst_pq.broker_invoice_id = bi.id AND gst_pq.charge_code = '256'
            LEFT OUTER JOIN broker_invoice_lines broker_fees ON broker_fees.broker_invoice_id = bi.id AND broker_fees.charge_code = '22'
            LEFT OUTER JOIN broker_invoice_lines hst_on ON hst_on.broker_invoice_id = bi.id AND hst_on.charge_code = '255'
            LEFT OUTER JOIN broker_invoice_lines hst_bc ON hst_bc.broker_invoice_id = bi.id AND hst_bc.charge_code = '250'
          WHERE e.importer_tax_id = '833231749RM0001' AND
                e.entry_type = '#{type}' AND
                bi.invoice_date >= '#{start_date_time}' AND
                bi.invoice_date <= '#{end_date_time}'
          GROUP BY bi.id
          ORDER BY bi.invoice_date;
        SQL
      end

    end
  end
end
      