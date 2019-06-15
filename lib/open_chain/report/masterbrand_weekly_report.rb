require 'open_chain/report/report_helper'
module OpenChain
  module Report
    class MasterbrandWeeklyReport
      include OpenChain::Report::ReportHelper

      def self.run_schedulable opts_hash={}
        vfi_cust_no = "KITCHEN"
        
        self.new.send_email('vfi_cust_no' => vfi_cust_no, 'email' => opts_hash['email'])
      end

      def get_local_time
        start_date_time = (ActiveSupport::TimeZone["Eastern Time (US & Canada)"].now - 9.days).beginning_of_day # "after 9 days ago"
        end_date_time = (ActiveSupport::TimeZone["Eastern Time (US & Canada)"].now - 3.days).end_of_day # "before 2 days ago"
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

      def create_workbook(vfi_cust_no)
        wb = XlsMaker.create_workbook "Masterbrand"
        start_date_time, end_date_time = query_time
        table_from_query wb.worksheet(0), query(vfi_cust_no, start_date_time, end_date_time), {6 => date_conversion_lambda, 7 => date_conversion_lambda} 
        wb
      end

      def date_conversion_lambda
        lambda { |result_set_row, raw_column_value| raw_column_value.in_time_zone("Eastern Time (US & Canada)").to_date if raw_column_value }
      end

      def send_email(settings)
        wb = create_workbook(settings['vfi_cust_no'])
        
        workbook_to_tempfile wb, 'Masterbrand-' do |t|
          start_date, end_date = formatted_local_time
          subject = "Masterbrand/KitchenCraft Report for the Period #{start_date} to #{end_date}"
          body = "<p>Report attached.<br>--This is an automated message, please do not reply. <br> This message was generated from VFI Track</p>".html_safe
          OpenMailer.send_simple_html(settings['email'], subject, body, t).deliver_now
        end
      end

      def query(vfi_cust_no, start_date_time, end_date_time)
        <<-SQL
            SELECT  316 AS 'Filer Code',
                    e.entry_number AS 'Entry Number',
                    e.broker_reference AS 'Broker Reference',
                    e.po_numbers AS 'Shipment Numbers',
                    e.entry_port_code AS 'Port of Entry Code',
                    p.name AS 'Port of Entry Name',
                    e.entry_filed_date AS 'Summary Filing Date',
                    e.arrival_date AS 'Import Date',
                    e.entered_value AS 'Entered Value',
                    e.total_duty AS 'Total Duty',
                    IFNULL(e.mpf, 0) AS 'MPF',
                    IFNULL(e.hmf, 0) AS 'HMF',
                    (IFNULL(e.total_fees, 0) - IFNULL(e.mpf, 0) + IFNULL(e.hmf, 0)) AS 'Other Fees',
                    e.total_fees AS 'Total Fees',
                    e.special_program_indicators AS 'SPI(s)',
                    e.recon_flags AS 'Recon Flags'
            FROM entries AS e INNER JOIN ports AS p ON e.entry_port_code = p.schedule_d_code
            WHERE e.customer_number = '#{sanitize vfi_cust_no}' AND 
                  e.release_date > '#{start_date_time}' AND 
                  e.release_date < '#{end_date_time}'
            ORDER BY e.release_date
        SQL
      end

    end
  end
end
