require 'open_chain/report/report_helper'

module OpenChain; module Report; class JJillWeeklyFreightSummaryReport
  include OpenChain::Report::ReportHelper

  def self.permission? user
    (user.company.master? || user.company.system_code=='JJILL') &&
    user.view_shipments?
  end

  def self.run_report run_by, settings={}
    self.new.run run_by, settings
  end

  def run run_by, settings
    wb = Spreadsheet::Workbook.new
    sheet_setup = {
      "PO Acknowledgement" => po_ack_qry,
      "PO Integrity" => po_integrity_qry,
      "Booking Exception" => booking_exception_qry,
      "Transit Time" => transit_time_qry,
      "Value In Transit" => value_in_transit_qry
    }
    sheet_setup.each {|k,v| sheet_from_query wb, k, v}
    workbook_to_tempfile wb, 'JJillWeeklyFreightSummary-'
  end

  private 

  def sheet_from_query workbook, name, query
    s = workbook.create_worksheet :name=>name
    table_from_query s, query
    s
  end
  def po_ack_qry
    q = <<QRY
SELECT 
orders.customer_order_number as 'Order Number', 
GROUP_CONCAT(DISTINCT (select string_value from custom_values where custom_definition_id = (select id from custom_definitions where label = 'Vendor Style' and module_type = 'Product') and customizable_id = order_lines.product_id) SEPARATOR ', ') as 'Vendor Style', 
(SELECT name FROM companies WHERE companies.id = orders.agent_id) as 'Agent',
(SELECT name FROM companies WHERE companies.id = orders.vendor_id) as 'Vendor',
orders.order_date as 'Created',
orders.last_revised_date as 'Last Revised',
DATEDIFF(now(),orders.last_revised_date) as 'Days Unapproved'
FROM orders
LEFT OUTER JOIN order_lines ON orders.id = order_lines.order_id
WHERE 
orders.importer_id = (SELECT id FROM companies WHERE system_code = 'JJILL')
AND (orders.approval_status is null OR orders.approval_status != 'Accepted')
AND (orders.fob_point IN ('VN','PH','ID'))
AND DATEDIFF(now(),orders.last_revised_date) > 7
GROUP BY orders.id
QRY
  end
  def po_integrity_qry
    q = <<QRY
SELECT orders.customer_order_number as 'PO', 
GROUP_CONCAT(DISTINCT (select string_value from custom_values where custom_definition_id = (select id from custom_definitions where label = 'Vendor Style' and module_type = 'Product') and customizable_id = order_lines.product_id) SEPARATOR ', ') as 'Vendor Style', 
(select name from companies where companies.id = orders.agent_id) as 'Agent', (select name from companies where companies.id = orders.vendor_id) as 'Vendor',  orders.mode AS 'Mode', orders.ship_window_start as 'Open Date', orders.ship_window_end as 'Closed Date', 
orders.first_expected_delivery_date as 'Requested Delivery Date', 
DATEDIFF(orders.ship_window_end,orders.ship_window_start) AS 'Closed v Open',
DATEDIFF(orders.first_expected_delivery_date,orders.ship_window_end) as 'Delivery v Closed'
FROM orders 
left outer join order_lines on orders.id = order_lines.order_id
WHERE 
  orders.importer_id = (SELECT id FROM companies WHERE system_code = 'JJILL')
  AND
  (
    orders.ship_window_start != orders.ship_window_end
    OR
    (orders.mode = 'Air' AND (DATEDIFF(orders.first_expected_delivery_date,orders.ship_window_end) < 7 OR DATEDIFF(orders.first_expected_delivery_date,orders.ship_window_end) > 10))
    OR
    (orders.mode = 'Ocean' AND (DATEDIFF(orders.first_expected_delivery_date,orders.ship_window_end) < 32 OR DATEDIFF(orders.first_expected_delivery_date,orders.ship_window_end) > 45))
  )
  AND
  (orders.ship_window_start >= now() AND orders.ship_window_end >= now())
GROUP BY orders.id
QRY
  end
  def booking_exception_qry
    q = <<QRY
SELECT `PO`, `Vendor Style`, `Agent`, `Vendor`, `PO Close Date`
FROM (
SELECT 
orders.customer_order_number AS 'PO', 
GROUP_CONCAT(DISTINCT (select string_value from custom_values where custom_definition_id = (select id from custom_definitions where label = 'Vendor Style' and module_type = 'Product') and customizable_id = order_lines.product_id) SEPARATOR ', ') as 'Vendor Style', 
(SELECT name FROM companies WHERE companies.id = orders.agent_id) as 'Agent',
(SELECT name FROM companies WHERE companies.id = orders.vendor_id) as 'Vendor',
orders.ship_window_end as 'PO Close Date',
SUM(ifnull(piece_sets.shipment_line_id,0)) as 'shipmentlines'
FROM orders
LEFT OUTER JOIN order_lines ON orders.id = order_lines.order_id
LEFT OUTER JOIN piece_sets ON piece_sets.order_line_id = order_lines.id AND piece_sets.shipment_line_id IS NOT NULL
WHERE 
orders.importer_id = (SELECT id FROM companies WHERE system_code = 'JJILL')
AND (orders.approval_status = 'Accepted')
AND DATEDIFF(orders.ship_window_end,now()) < 14
AND (orders.fob_point IN ('VN','PH','ID'))
GROUP BY orders.id
) x WHERE x.shipmentlines = 0    
QRY
  end
  def transit_time_qry
    q = <<QRY
SELECT 
shipments.house_bill_of_lading as 'HBOL',
shipments.master_bill_of_lading as 'MBOL',
GROUP_CONCAT(DISTINCT containers.container_number SEPARATOR ', ') as 'Containers',
'SOON' as 'Origin',
shipments.cargo_on_hand_date as 'Freight Received',
shipments.departure_date as 'Departure Date',
'SOON' as 'Transhp Port',
shipments.mode as 'Mode',
'SOON' as 'Load',
'SOON' as 'Carrier',
'SOON' as 'DestinationPort',
shipments.arrival_port_date as 'Arrival Port',
shipments.delivered_date as 'Delivered Date',
DATEDIFF(shipments.arrival_port_date,shipments.cargo_on_hand_date) as 'TT to Port',
DATEDIFF(shipments.delivered_date,shipments.cargo_on_hand_date) as 'TT to DC',
SUM(shipment_lines.cbms) as 'Vol',
SUM(shipment_lines.gross_kgs) as 'Gross Weight',
'SOON' as 'Terms'
FROM shipments
LEFT OUTER JOIN shipment_lines on shipments.id = shipment_lines.shipment_id
LEFT OUTER JOIN containers on containers.id = shipment_lines.container_id
WHERE
shipments.importer_id = (SELECT id FROM companies WHERE system_code = 'JJILL')
AND
shipments.delivered_date > DATE_ADD(now(), INTERVAL -12 MONTH)
GROUP BY shipments.id    
QRY
  end
  def value_in_transit_qry
    q = <<QRY
SELECT 
shipments.house_bill_of_lading as 'HBOL',
shipments.mode as 'Mode',
orders.customer_order_number as 'PO Number',
GROUP_CONCAT(DISTINCT containers.container_number SEPARATOR ', ') as 'Containers',
GROUP_CONCAT(DISTINCT vendor.name SEPARATOR ', ') as 'Vendor',
shipments.est_departure_date,
shipments.est_arrival_port_date,
GROUP_CONCAT(DISTINCT (select string_value from custom_values where custom_definition_id = (select id from custom_definitions where label = 'Vendor Style' and module_type = 'Product') and customizable_id = order_lines.product_id) SEPARATOR ', ') as 'Vendor Style', 
sum(shipment_lines.carton_qty) as 'Cartons',
sum(shipment_lines.quantity) as 'Pieces',
sum(shipment_lines.gross_kgs) as 'Gross Weight',
sum(shipment_lines.cbms) as 'CBMs',
SUM(shipment_lines.quantity * order_lines.price_per_unit) as 'Value',
shipments.cargo_on_hand_date as 'Freight Received',
shipments.departure_date as 'Departure Date',
shipments.est_delivery_date as 'Est Delivery',
shipments.delivered_date as 'Act Delivery'
FROM shipments
LEFT OUTER JOIN shipment_lines on shipments.id = shipment_lines.shipment_id
LEFT OUTER JOIN containers on shipment_lines.container_id = containers.id
LEFT OUTER JOIN piece_sets ON piece_sets.shipment_line_id = shipment_lines.id
LEFT OUTER JOIN order_lines ON order_lines.id = piece_sets.order_line_id
LEFT OUTER JOIN orders ON orders.id = order_lines.order_id
LEFT OUTER JOIN companies as vendor ON vendor.id = orders.vendor_id
WHERE
shipments.importer_id = (SELECT id FROM companies WHERE system_code = 'JJILL')
AND
(shipments.delivered_date IS NULL OR shipments.delivered_date > DATE_ADD(now(), INTERVAL -2 DAY))
GROUP BY shipments.id, orders.id    
QRY
  end
end; end; end