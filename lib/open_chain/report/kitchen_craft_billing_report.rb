require 'open_chain/report/report_helper'
module OpenChain
  module Report
    class KitchenCraftBillingReport
      include OpenChain::Report::ReportHelper

      def initialize opts = {}
        @parameters = opts
      end

      def self.permission? user
        (Rails.env=='development' || MasterSetup.get.system_code=='www-vfitrack-net') && user.company.master?
      end

      def run 
        start_date, end_date = parse_date_parameters
        sql = <<-SQL
          SELECT e.broker_reference as 'FILE NO', substr(e.entry_number, 1, 3) as 'FILER CODE', substr(e.entry_number, 4) as 'Entry NO', replace(e.po_numbers, '\n', ', ') as 'CUST. REF', 
          e.carrier_code as 'SCAC', replace(e.master_bills_of_lading, '\n', ', ') as 'MASTER BILLS', replace(e.container_numbers, '\n', ', ') as 'CONTAINER NOs', 
          e.release_date as 'RELEASE DATE', e.total_invoiced_value as 'VALUE ENTERED', 
          (SELECT ifnull(sum(charge_amount), 0) FROM broker_invoice_lines INNER JOIN broker_invoices ON broker_invoices.id = broker_invoice_lines.broker_invoice_id WHERE broker_invoices.entry_id = e.id AND charge_code = '0001') as 'DUTY',
          (SELECT ifnull(sum(charge_amount), 0) FROM broker_invoice_lines INNER JOIN broker_invoices ON broker_invoices.id = broker_invoice_lines.broker_invoice_id WHERE broker_invoices.entry_id = e.id AND charge_code = '0009') as 'ADDITIONAL CLASSIFICATIONS',
          (SELECT ifnull(sum(charge_amount), 0) FROM broker_invoice_lines INNER JOIN broker_invoices ON broker_invoices.id = broker_invoice_lines.broker_invoice_id WHERE broker_invoices.entry_id = e.id AND charge_code = '0008') as 'ADDITIONAL INVOICES',
          (SELECT ifnull(sum(charge_amount), 0) FROM broker_invoice_lines INNER JOIN broker_invoices ON broker_invoices.id = broker_invoice_lines.broker_invoice_id WHERE broker_invoices.entry_id = e.id AND charge_code = '0220') as 'BORDER CLEARANCE',
          (SELECT ifnull(sum(charge_amount), 0) FROM broker_invoice_lines INNER JOIN broker_invoices ON broker_invoices.id = broker_invoice_lines.broker_invoice_id WHERE broker_invoices.entry_id = e.id AND charge_code = '0007') as 'CUSTOMS ENTRY',
          (SELECT ifnull(sum(charge_amount), 0) FROM broker_invoice_lines INNER JOIN broker_invoices ON broker_invoices.id = broker_invoice_lines.broker_invoice_id WHERE broker_invoices.entry_id = e.id AND charge_code = '0162') as 'DISBURSEMENT FEES',
          (SELECT ifnull(sum(charge_amount), 0) FROM broker_invoice_lines INNER JOIN broker_invoices ON broker_invoices.id = broker_invoice_lines.broker_invoice_id WHERE broker_invoices.entry_id = e.id AND charge_code = '0198') as 'LACEY ACT FILING',
          (SELECT ifnull(sum(charge_amount), 0) FROM broker_invoice_lines INNER JOIN broker_invoices ON broker_invoices.id = broker_invoice_lines.broker_invoice_id WHERE broker_invoices.entry_id = e.id AND charge_code = '0022') as 'MISSING DOCUMENTS',
          (SELECT ifnull(sum(charge_amount), 0) FROM broker_invoice_lines INNER JOIN broker_invoices ON broker_invoices.id = broker_invoice_lines.broker_invoice_id WHERE broker_invoices.entry_id = e.id AND charge_code = '0221') as 'OBTAIN IRS NO.',
          (SELECT ifnull(sum(charge_amount), 0) FROM broker_invoice_lines INNER JOIN broker_invoices ON broker_invoices.id = broker_invoice_lines.broker_invoice_id WHERE broker_invoices.entry_id = e.id AND charge_code = '0222') as 'OBTAIN IRS NO. CF FROM 5106',
          (SELECT ifnull(sum(invoice_total), 0) FROM broker_invoices WHERE broker_invoices.entry_id = e.id) as 'BILLED TO-DATE'
          FROM entries e 
          WHERE
          e.customer_number = 'KITCHEN'
          AND e.release_date > '#{start_date.utc.to_s(:db)}'
          AND e.release_date < '#{end_date.utc.to_s(:db)}'
          AND e.broker_reference LIKE '991%'
          ORDER BY e.release_date ASC
        SQL

        conversions = {"RELEASE DATE" => lambda{|row, value| value.nil? ? "" : value.in_time_zone(Time.zone).to_date}}
        wb = Spreadsheet::Workbook.new
        sheet = wb.create_worksheet :name=>"KitchenCraft"
        table_from_query sheet, sql, conversions
        workbook_to_tempfile wb, "KitchenCraft Entries #{start_date.strftime("%Y-%m-%d")} - #{end_date.strftime("%Y-%m-%d")}"
      end

      # run_by required by reporting interface
      def self.run_report run_by, opts = {}
        KitchenCraftBillingReport.new(opts).run
      end

      private
        def parse_date_parameters
          [Time.zone.parse(@parameters['start_date']), Time.zone.parse(@parameters['end_date'])]
        end
    end
  end
end