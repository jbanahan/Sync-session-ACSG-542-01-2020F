require 'open_chain/report/report_helper'
module OpenChain
  module Report
    class FootLockerCaBillingSummary
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
SELECT 
  ent.entry_number as "Entry Number", 
  ent.release_date as "Release", 
  ent.entry_port_code as "Entry Port", 
  ent.broker_reference as "File Number", 
  ent.master_bills_of_lading as "MBOLs", 
  ent.house_bills_of_lading as "HBOLs", 
  ci.vendor_name as "Vendor", 
  cil.line_number as "Invoice Line", 
  ci.invoice_number as "Commercial Invoice Number", 
  cit.hts_code as "HTS Code", 
  cil.quantity as "Invoice Quantity", 
  cil.unit_of_measure as "Invoice UOM", 
  cit.classification_qty_1 as "Tariff Quantity", 
  cit.classification_uom_1 as "Tariff UOM", 
  cit.entered_value as "Entered Value", 
  cil.value as "Invoice Value", 
  cit.duty_amount as "Duty Amount", 
  cit.gst_amount as "GST Amount",
  cil.po_number as "PO Number", 
  cil.part_number as "Style", 
  bi.invoice_number as "Invoice Number", 
  bi.invoice_total as "Invoice Total", 
  (SELECT sum(bil.charge_amount) FROM broker_invoice_lines bil WHERE bil.broker_invoice_id = bi.id AND bil.charge_code IN ('250', '251', '252', '253', '254', '255', '256', '257', '258', '259', '260') AND bil.charge_type = 'R') as 'HST Total Amount',
  ((bi.invoice_total/ent.total_units)*cil.quantity) as "Entry Fee Per Line",
  ent.container_numbers as "Containers"
FROM broker_invoices bi
INNER JOIN entries ent ON bi.entry_id = ent.id
INNER JOIN commercial_invoices ci ON ent.id = ci.entry_id
INNER JOIN commercial_invoice_lines cil ON ci.id = cil.commercial_invoice_id
INNER JOIN commercial_invoice_tariffs cit ON cit.commercial_invoice_line_id = cil.id
WHERE 
  ent.importer_tax_id = '134482702RM0001' 
  AND bi.invoice_date BETWEEN "#{start_date}" AND "#{end_date}"
QRY
        wb = Spreadsheet::Workbook.new
        sheet = wb.create_worksheet :name=>'CA Billing Summary'
        # We need to translate the release date into Eastern Timezone before trimming the time portion off
        conversions = {"Release" => datetime_translation_lambda("Eastern Time (US & Canada)", true)}
        table_from_query sheet, qry, conversions
        workbook_to_tempfile wb, 'FootLockerCaBillingSummary-'
      end
    end
  end
end
