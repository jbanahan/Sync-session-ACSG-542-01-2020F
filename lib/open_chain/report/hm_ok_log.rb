require 'open_chain/report/report_helper'
module OpenChain; module Report; class HmOkLog
  include OpenChain::Report::ReportHelper

  def run_schedulable opts_hash={}
    u = User.find_by_username opts_hash['username']
    raise "#{u.username} does not have permission to run report." unless self.class.permission? u
    f = self.run(u,coast: opts_hash['coast'])
    begin
      def f.original_file_name; 'ok_log.xls'; end;
      email_to = opts_hash['email']
      OpenMailer.send_simple_html(email_to, "Vandegrift OK Log - #{opts_hash['coast']}", "H&M OK Log", [f]).deliver!
    ensure
      f.unlink
    end
  end

  def self.permission? user
    user.view_entries? && (user.company.master? || user.company.alliance_customer_number=='HENNE') 
  end

  def self.run_report run_by, settings={}
    self.new.run run_by, settings
  end

  def run run_by, settings
    coast = settings[:coast]
    raise "Invalid coast." unless ['east','west'].include? coast.downcase
    tz = coast.downcase=='west' ? 'US/Pacific' : 'US/Eastern'
    qry = <<QRY
SELECT 
DATE_FORMAT(CONVERT_TZ(commercial_invoices.created_at,'UTC','#{tz}'),"%Y-%m-%d %H:%i") as 'CREATED DATE (#{coast.downcase=='west' ? 'PST' : 'EST'})',
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
commercial_invoices.destination_code = "#{coast}" AND
commercial_invoices.entry_id is null AND
commercial_invoices.importer_id = (SELECT id FROM companies WHERE system_code = "HENNE" limit 1)
and (docs_received_date is null OR docs_received_date > date_add(now(),INTERVAL -90 day))
order by commercial_invoices.created_at desc
QRY
# order by if(docs_ok_date is null,0,1), docs_received_date DESC;
    wb = Spreadsheet::Workbook.new
    sheet = wb.create_worksheet :name=>coast
    table_from_query sheet, qry
    workbook_to_tempfile wb, 'HmOKLog-'
  end

end; end; end