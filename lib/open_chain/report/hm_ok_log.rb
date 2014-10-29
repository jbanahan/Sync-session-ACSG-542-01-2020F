require 'open_chain/report/report_helper'
module OpenChain; module Report; class HmOkLog
  include OpenChain::Report::ReportHelper

  def self.run_schedulable opts_hash={}
    u = User.find_by_username opts_hash['username']
    raise "#{u.username} does not have permission to run report." unless self.permission? u
    f = self.new.run(u)
    begin
      def f.original_file_name; 'ok_log.xls'; end;
      email_to = opts_hash['email']
      OpenMailer.send_simple_html(email_to, "Vandegrift OK Log", "H&M OK Log", [f]).deliver!
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
    wb = Spreadsheet::Workbook.new
    ['East','West'].each {|coast| run_coast(wb,coast)}
    run_unmatched wb
    workbook_to_tempfile wb, 'HmOKLog-'
  end

  private 
  def run_unmatched wb
    qry = <<QRY
select  
part_number.string_value as 'Order Number',
shipments.importer_reference as 'Import Number',
shipments.vessel as 'Vessel',
shipments.voyage as 'Voyage',
shipments.est_arrival_port_date as 'ETA Port',
shipments.est_departure_date as 'Departure',
shipments.mode as 'Mode',
shipment_lines.quantity as 'Quantity',
shipment_lines.carton_qty as 'Cartons',
shipment_lines.fcr_number as 'FCR Number',
containers.container_number as 'Container',
containers.container_size as 'Container Size'
from shipments
left outer join containers on containers.shipment_id = shipments.id
inner join shipment_lines on shipment_lines.shipment_id = shipments.id
inner join products on products.id = shipment_lines.product_id
inner join custom_values part_number on part_number.custom_definition_id = (SELECT id from custom_definitions where module_type = 'Product' and label ='Part Number') and part_number.customizable_id = products.id and part_number.customizable_type = 'Product'
inner join piece_sets on piece_sets.shipment_line_id = shipment_lines.id
inner join commercial_invoice_lines on commercial_invoice_lines.id = piece_sets.commercial_invoice_line_id
inner join commercial_invoices on commercial_invoices.id = commercial_invoice_lines.commercial_invoice_id
where shipments.importer_id = (select id from companies where system_code = 'HENNE')
and commercial_invoices.docs_received_date is null
and shipments.est_arrival_port_date > DATE_ADD(now(),INTERVAL -45 DAY)
order by shipments.est_arrival_port_date asc
QRY
    sheet = wb.create_worksheet :name=>'Unmatched'
    table_from_query sheet, qry 
  end
  def run_coast wb, coast
    raise "Invalid coast." unless ['east','west'].include? coast.downcase
    tz = coast.downcase=='west' ? 'US/Pacific' : 'US/Eastern'
    qry = <<QRY
SELECT DISTINCT
DATE_FORMAT(CONVERT_TZ(commercial_invoices.created_at,'UTC','#{tz}'),"%Y-%m-%d %H:%i") as 'CREATED DATE (#{coast.downcase=='west' ? 'PST' : 'EST'})',
commercial_invoices.destination_code as 'COAST',
commercial_invoices.invoice_number as 'PO',
shipments.importer_reference as 'IMPORT NUMBER',
commercial_invoice_lines.quantity as 'PCS',
commercial_invoices.total_quantity as 'CTNS',
commercial_invoice_lines.unit_price as 'UNIT PRICE',
commercial_invoice_lines.currency as 'CURRENCY',
commercial_invoices.invoice_value_foreign as 'INVOICE TOTAL',
commercial_invoice_tariffs.hts_code as 'US HTS#',
commercial_invoices.mfid as 'MID',
commercial_invoice_lines.country_origin_code as 'ORIGIN',
shipments.est_arrival_port_date as 'ETA PORT',
shipment_lines.fcr_number as 'FCR NUMBER',
containers.container_number as 'CONTAINER',
commercial_invoices.docs_received_date as 'DOCS RCVD',
commercial_invoices.docs_ok_date as 'DOCS OK',
commercial_invoices.issue_codes as 'ISSUES',
commercial_invoices.rater_comments as 'COMMENTS',
official_tariff_meta_datas.summary_description as 'HTS Description'
FROM commercial_invoices
INNER JOIN commercial_invoice_lines ON commercial_invoice_lines.commercial_invoice_id = commercial_invoices.id
INNER JOIN commercial_invoice_tariffs ON commercial_invoice_tariffs.commercial_invoice_line_id = commercial_invoice_lines.id
LEFT OUTER JOIN official_tariff_meta_datas ON official_tariff_meta_datas.hts_code = commercial_invoice_tariffs.hts_code and official_tariff_meta_datas.country_id = (select id from countries where iso_code = 'US')
LEFT OUTER JOIN piece_sets on piece_sets.commercial_invoice_line_id = commercial_invoice_lines.id and piece_sets.shipment_line_id is not null
LEFT OUTER JOIN shipment_lines on shipment_lines.id = piece_sets.shipment_line_id
LEFT OUTER JOIN shipments on shipments.id = shipment_lines.shipment_id
LEFT OUTER JOIN containers on shipment_lines.container_id = containers.id
WHERE
commercial_invoices.destination_code = "#{coast}" AND
commercial_invoices.entry_id is null AND
commercial_invoices.importer_id = (SELECT id FROM companies WHERE system_code = "HENNE" limit 1)
and (commercial_invoices.docs_received_date is null OR commercial_invoices.docs_received_date > date_add(now(),INTERVAL -90 day))
order by commercial_invoices.created_at desc
QRY
    sheet = wb.create_worksheet :name=>coast
    table_from_query sheet, qry
  end
end; end; end