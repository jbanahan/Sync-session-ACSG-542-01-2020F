require 'open_chain/report/report_helper'

module OpenChain; module Report; class JJillWeeklyFreightSummaryReport
  include OpenChain::Report::ReportHelper
  include OpenChain::CustomHandler::JJill::JJillCustomDefinitionSupport

  def self.permission? user
    (user.company.master? || user.company.system_code=='JJILL') &&
    user.view_shipments?
  end

  def self.run_report run_by, settings={}
    self.new.run run_by, settings
  end

  def initialize
    @cdefs ||= self.class.prep_custom_definitions [:original_gac_date]
  end

  def run run_by, settings
    wb = Spreadsheet::Workbook.new
    sheet_setup = {
      "PO Acknowledgement" => po_ack_qry,
      "PO Integrity" => po_integrity_qry,
      "Booking Exception" => booking_exception_qry,
      "Transit Time" => transit_time_qry,
      "Value In Transit" => value_in_transit_qry,
      "Booking Integrity" => booking_integrity_qry,
      "Order Fulfillment" => order_fulfillment_qry
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
orders.ship_window_start as 'Ship Window Start',
orders.order_date as 'Created',
orders.last_revised_date as 'Last Revised',
DATEDIFF(now(),orders.last_revised_date) as 'Days Unapproved'
FROM orders
LEFT OUTER JOIN order_lines ON orders.id = order_lines.order_id
WHERE
orders.closed_at is null
AND orders.importer_id = (SELECT id FROM companies WHERE system_code = 'JJILL')
AND (orders.approval_status is null OR orders.approval_status != 'Accepted')
AND (orders.fob_point IN ('VN','PH','ID'))
AND DATEDIFF(now(),orders.last_revised_date) > 7
GROUP BY orders.id
QRY
    q
  end
  def po_integrity_qry
    q = <<QRY
SELECT orders.customer_order_number as 'PO',
GROUP_CONCAT(DISTINCT (select string_value from custom_values where custom_definition_id = (select id from custom_definitions where label = 'Vendor Style' and module_type = 'Product') and customizable_id = order_lines.product_id) SEPARATOR ', ') as 'Vendor Style',
(select name from companies where companies.id = orders.agent_id) as 'Agent', (select name from companies where companies.id = orders.vendor_id) as 'Vendor',  orders.mode AS 'Mode', orders.ship_window_start as 'Ship Window Start', orders.ship_window_end as 'Ship Window End',
orders.first_expected_delivery_date as 'Requested Delivery Date',
DATEDIFF(orders.ship_window_end,orders.ship_window_start) AS 'Closed v Open',
DATEDIFF(orders.first_expected_delivery_date,orders.ship_window_end) as 'Delivery v Closed'
FROM orders
left outer join order_lines on orders.id = order_lines.order_id
WHERE
orders.closed_at is null
  AND
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
    q
  end
  def booking_exception_qry
    q = <<QRY
SELECT `PO`, `Vendor Style`, `Agent`, `Vendor`, `Ship Window End`
FROM (
SELECT
orders.customer_order_number AS 'PO',
GROUP_CONCAT(DISTINCT (select string_value from custom_values where custom_definition_id = (select id from custom_definitions where label = 'Vendor Style' and module_type = 'Product') and customizable_id = order_lines.product_id) SEPARATOR ', ') as 'Vendor Style',
(SELECT name FROM companies WHERE companies.id = orders.agent_id) as 'Agent',
(SELECT name FROM companies WHERE companies.id = orders.vendor_id) as 'Vendor',
orders.ship_window_end as 'Ship Window End',
SUM(ifnull(piece_sets.shipment_line_id,0)) as 'shipmentlines'
FROM orders
LEFT OUTER JOIN order_lines ON orders.id = order_lines.order_id
LEFT OUTER JOIN piece_sets ON piece_sets.order_line_id = order_lines.id AND piece_sets.shipment_line_id IS NOT NULL
WHERE
orders.closed_at is null
  AND
orders.importer_id = (SELECT id FROM companies WHERE system_code = 'JJILL')
AND (orders.approval_status = 'Accepted')
AND DATEDIFF(orders.ship_window_end,now()) < 14
AND (orders.fob_point IN ('VN','PH','ID'))
GROUP BY orders.id
) x WHERE x.shipmentlines = 0
QRY
    q
  end
  def transit_time_qry
    q = <<QRY
SELECT
shipments.house_bill_of_lading as 'HBOL',
shipments.master_bill_of_lading as 'MBOL',
GROUP_CONCAT(DISTINCT containers.container_number SEPARATOR ', ') as 'Containers',
shipments.receipt_location as 'Origin',
shipments.cargo_on_hand_date as 'Freight Received',
shipments.departure_date as 'Departure Date',
'SOON' as 'Tranship Port',
shipments.mode as 'Mode',
shipments.shipment_type as 'Load',
shipments.vessel_carrier_scac as 'Carrier',
'SOON' as 'Destination Port',
shipments.arrival_port_date as 'Arrival Port',
shipments.delivered_date as 'Delivered Date',
DATEDIFF(shipments.arrival_port_date,shipments.cargo_on_hand_date) as 'TT to Port',
DATEDIFF(shipments.delivered_date,shipments.cargo_on_hand_date) as 'TT to DC',
ROUND((select sum((carton_sets.length_cm * carton_sets.width_cm * carton_sets.height_cm * carton_sets.carton_qty)/1000000) from carton_sets where carton_sets.shipment_id = shipments.id),2) as 'CBMS',
ROUND((select sum(carton_sets.gross_kgs * carton_sets.carton_qty) from carton_sets where carton_sets.shipment_id = shipments.id),2) as 'Gross KGS',
ROUND((select GREATEST(sum((carton_sets.length_cm * carton_sets.width_cm * carton_sets.height_cm * carton_sets.carton_qty))/6000,sum(carton_sets.gross_kgs * carton_sets.carton_qty)) FROM carton_sets where carton_sets.shipment_id = shipments.id),2) as 'Calculated Chargeable Weight',
shipments.freight_terms as 'Terms'
FROM shipments
LEFT OUTER JOIN shipment_lines on shipments.id = shipment_lines.shipment_id
LEFT OUTER JOIN containers on containers.id = shipment_lines.container_id
WHERE
shipments.importer_id = (SELECT id FROM companies WHERE system_code = 'JJILL')
and
shipments.delivered_date > DATE_ADD(now(), INTERVAL -12 MONTH)
GROUP BY shipments.id
QRY
    q
  end
  def value_in_transit_qry
    q = <<QRY
  SELECT
  shipments.house_bill_of_lading as 'HBOL',
  shipments.mode as 'Mode',
  orders.customer_order_number as 'PO Number',
  GROUP_CONCAT(DISTINCT containers.container_number SEPARATOR ', ') as 'Containers',
  GROUP_CONCAT(DISTINCT vendor.name SEPARATOR ', ') as 'Vendor',
  shipments.est_departure_date as 'Est Departure Date',
  shipments.est_arrival_port_date as 'Est Arrival Date',
  GROUP_CONCAT(DISTINCT (select string_value from custom_values where custom_definition_id = (select id from custom_definitions where label = 'Vendor Style' and module_type = 'Product') and customizable_id = order_lines.product_id) SEPARATOR ', ') as 'Vendor Style',
  sum(shipment_lines.carton_qty) as 'Cartons',
  sum(shipment_lines.quantity) as 'Pieces',
  sum(shipment_lines.gross_kgs) as 'Gross Weight',
  sum(shipment_lines.cbms) as 'CBMs',
  order_lines.price_per_unit as 'Unit Price',
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
  AND
  (shipments.cargo_on_hand_date IS NOT NULL)
  AND
  (shipments.canceled_date IS NULL)
  GROUP BY shipments.id, orders.id, order_lines.price_per_unit
QRY
    q
  end
  def booking_integrity_qry
<<QRY
SELECT
shipments.receipt_location as 'Origin',
shipments.booking_number as 'Booking #',
shipments.booking_mode as 'Booked Mode',
shipments.booking_shipment_type as 'Booked Load',
shipments.booking_carrier as 'Booked Carrier',
shipments.booking_vessel as 'Booked Vessel',
destination_port.name as 'Booked Destination',
DATE_FORMAT(shipments.booking_est_departure_date,'%m/%d/%Y') as 'Booked Origin ETD',
DATE_FORMAT(shipments.booking_est_arrival_date,'%m/%d/%Y') as 'Booked Destination ETA',
shipments.house_bill_of_lading as 'Actual Shipment #',
shipments.mode as 'Actual Mode',
shipments.shipment_type as 'Actual Load',
shipments.vessel_carrier_scac as 'Actual Carrier',
shipments.vessel as 'Actual Vessel',
destination_port.name as 'Actual Destination',
DATE_FORMAT(shipments.departure_date,'%m/%d/%Y') as 'Actual Departure',
DATE_FORMAT(shipments.arrival_port_date,'%m/%d/%Y') as 'Actual Arrival',
DATEDIFF(shipments.departure_date,shipments.booking_est_departure_date) as 'Departure Variance',
DATEDIFF(shipments.arrival_port_date,shipments.booking_est_arrival_date) as 'Arrival Variance',
shipments.delay_reason_codes as 'Shipment Note'
FROM
shipments
INNER JOIN ports as destination_port ON destination_port.id = shipments.destination_port_id
WHERE
shipments.importer_id = (SELECT id FROM companies WHERE system_code = 'JJILL')
AND
DATEDIFF(now(),shipments.arrival_port_date) < 365
QRY
  end
  def order_fulfillment_qry
    <<QRY
SELECT
  `Origin`,`Vendor`,`Factory`,`PO Number`,`PO Qty`,`PO GAC`,
  `Booking #`,`Book Mode`,`Booked Qty`,`Booking Cut Off`,
  `Shipment #`,`Ship Mode`,`Shipped Qty`, `Shipment Cut Off`, `FCR Date`,
  DATEDIFF(`FCR Date`,`Shipment Cut Off`) as 'FCR vs. Ship Cutoff',
  DATEDIFF(`FCR Date`,`Booking Cut Off`) as 'FCR vs. Book Cutoff',
  DATEDIFF(`FCR Date`,`PO GAC`) as 'FCR vs. GAC',
  `Shipped Qty` - `Booked Qty` as 'Shipped Qty vs. Booked Qty',
  `Shipped Qty` - `PO Qty` as 'Shipped Qty vs. Ordered Qty'
FROM(SELECT
  shipments.receipt_location as 'Origin',
  vendor.name as 'Vendor',
  factory.name as 'Factory',
  orders.customer_order_number as 'PO Number',
  (SELECT SUM(quantity) FROM order_lines WHERE order_id = orders.id GROUP BY orders.id) as 'PO Qty',
  NULL as 'PO GAC',
  shipments.booking_number as 'Booking #',
  shipments.booking_mode as 'Book Mode',
  (SELECT SUM(quantity) FROM booking_lines WHERE order_id = orders.id OR (order_lines.order_id = orders.id AND order_lines.id = order_line_id) GROUP BY orders.id) as 'Booked Qty',
  shipments.booking_cutoff_date as 'Booking Cut Off',
  shipments.house_bill_of_lading as 'Shipment #',
  shipments.mode as 'Ship Mode',
  (SELECT SUM(shipment_lines.quantity) FROM shipment_lines
  WHERE id IN (SELECT shipment_line_id from piece_sets
    inner join order_lines
  where order_lines.id = piece_sets.order_line_id and orders.id = order_lines.order_id group by order_lines.order_id)
  ) AS `Shipped Qty`,
  NULL as 'Shipment Cut Off',
  shipments.cargo_on_hand_date as 'FCR Date'
FROM shipments
  LEFT OUTER JOIN shipment_lines on shipments.id = shipment_lines.shipment_id
  INNER JOIN piece_sets ON piece_sets.shipment_line_id = shipment_lines.id
  INNER JOIN order_lines ON order_lines.id = piece_sets.order_line_id
  INNER JOIN orders ON orders.id = order_lines.order_id
  LEFT OUTER JOIN booking_lines on orders.id = booking_lines.order_id OR order_lines.id = booking_lines.order_line_id
  LEFT OUTER JOIN companies as vendor ON vendor.id = orders.vendor_id
  LEFT OUTER JOIN companies as factory ON factory.id = orders.factory_id
WHERE
  shipments.importer_id = (SELECT id FROM companies WHERE system_code = 'JJILL')
AND
  DATEDIFF(now(),shipments.arrival_port_date) < 365
GROUP BY shipments.id, orders.id) as data
QRY
  end
end; end; end
