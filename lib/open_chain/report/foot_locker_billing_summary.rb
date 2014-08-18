require 'open_chain/report/report_helper'
module OpenChain
  module Report
    class FootLockerBillingSummary
      include OpenChain::Report::ReportHelper

      def self.permission? user
        user.company.master? && user.view_broker_invoices?
      end

      def self.run_report run_by, settings={}
        self.new.run run_by, settings
      end

      def run run_by, settings
        start_date = sanitize_date_string settings['start_date']
        end_date = sanitize_date_string settings['end_date']
        qry = <<QRY
select 
ent.entry_number as "Entry Number", 
ent.arrival_date as "Arrival", 
ent.release_date as "Release", 
ent.entry_port_code as "Entry Port", 
ent.broker_reference as "File Number", 
ent.customer_name as "Customer Name", 
ent.export_date as "Export Date", 
ent.master_bills_of_lading as "MBOLs", 
ent.house_bills_of_lading as "HBOLs", 
ci.mfid as "MID", 
ci.vendor_name as "Vendor", 
cil.line_number as "Invoice Line", 
ci.invoice_number as "Commercial Invoice Number", 
cit.tariff_description as "Item Description", 
cit.hts_code as "HTS Code", 
cit.gross_weight as "Gross Weight",
cil.quantity as "Invoice Quantity", 
cil.unit_of_measure as "Invoice UOM", 
cit.classification_qty_1 as "Tariff Quantity", 
cit.classification_uom_1 as "Tariff UOM", 
cit.entered_value as "Entered Value", 
cil.value as "Invoice Value", 
cit.duty_amount as "Duty Amount", 
cit.duty_rate as "Duty Rate", 
cil.cotton_fee as "Cotton Fee", 
cil.hmf as "HMF", 
cil.mpf as "MPF", 
cil.department as "Department", 
cil.po_number as "PO Number", 
cil.part_number as "Style", 
(ent.broker_reference + bi.suffix) as "Invoice Number", 
bi.invoice_total as "Invoice Total", 
((bi.invoice_total/ent.total_units)*cil.quantity) as "Entry Fee Per Line", 
ent.total_packages as "Total Packages",
ent.container_numbers as "Containers"
from broker_invoices bi
inner join entries ent on bi.entry_id = ent.id
inner join commercial_invoices ci on ent.id = ci.entry_id
inner join commercial_invoice_lines cil on ci.id = cil.commercial_invoice_id
inner join commercial_invoice_tariffs cit on cit.commercial_invoice_line_id = cil.id
where bi.customer_number = "FOOLO" and bi.invoice_date between "#{start_date}" and "#{end_date}"
QRY
        wb = Spreadsheet::Workbook.new
        sheet = wb.create_worksheet :name=>'Billing Summary'
        # Translate the release, arrival date into Eastern Timezone before trimming the time portion off
        # Moved out of the query because if done in the query we're converting the UTC time to a date and potentially 
        # reporting the wrong date if the release is done between 8-12PM EDT.
        dt_lambda = datetime_translation_lambda("Eastern Time (US & Canada)", true)
        conversions = {"Release" => dt_lambda, "Arrival" => dt_lambda}
        table_from_query sheet, qry, conversions
        workbook_to_tempfile wb, 'FootLockerBillingSummary-'
      end
    end
  end
end
