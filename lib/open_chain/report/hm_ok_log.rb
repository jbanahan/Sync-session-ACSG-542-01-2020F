require 'open_chain/report/report_helper'
module OpenChain; module Report; class HmOkLog
  include OpenChain::Report::ReportHelper

  def self.permission? user
    user.view_entries? && (user.company.master? || user.company.alliance_customer_number=='HENNE') 
  end

  def self.run_report run_by, settings={}
    self.new.run run_by, settings
  end

  def run run_by, settings
    qry = <<QRY
SELECT 
commercial_invoices.destination_code as 'COAST',
commercial_invoices.invoice_number as 'PO',
commercial_invoice_lines.quantity as 'PCS',
commercial_invoices.total_quantity as 'CTNS',
commercial_invoice_lines.unit_price as 'UNIT PRICE',
commercial_invoice_lines.currency as 'CURRENCY',
commercial_invoices.invoice_value_foreign as 'INVOICE TOTAL',
commercial_invoice_tariffs.hts_code as 'US HTS#',
commercial_invoices.mfid as 'MID',
commercial_invoice_lines.country_origin_code as 'ORIGIN',
commercial_invoices.docs_received_date as 'DOCS RCVD',
commercial_invoices.docs_ok_date as 'DOCS OK',
commercial_invoices.issue_codes as 'ISSUES',
commercial_invoices.rater_comments as 'COMMENTS'
FROM commercial_invoices
INNER JOIN commercial_invoice_lines ON commercial_invoice_lines.commercial_invoice_id = commercial_invoices.id
INNER JOIN commercial_invoice_tariffs ON commercial_invoice_tariffs.commercial_invoice_line_id = commercial_invoice_lines.id
WHERE
commercial_invoices.destination_code = "DESTCODE" AND
commercial_invoices.entry_id is null AND
commercial_invoices.importer_id = (SELECT id FROM companies WHERE system_code = "HENNE" limit 1)
and (docs_ok_date is null OR docs_ok_date > date_add(now(),INTERVAL -90 day))
order by if(docs_ok_date is null,0,1), docs_received_date DESC;
QRY
    wb = Spreadsheet::Workbook.new
    ['East','West'].each do |coast|
      sheet = wb.create_worksheet :name=>coast
      table_from_query sheet, qry.gsub('DESTCODE',coast)
    end
    workbook_to_tempfile wb, 'HmOKLog-'
  end

end; end; end