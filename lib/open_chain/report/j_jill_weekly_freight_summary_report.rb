require 'open_chain/report/report_helper'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module Report; class JJillWeeklyFreightSummaryReport
  include OpenChain::Report::ReportHelper
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def self.permission? user
    MasterSetup.get.custom_feature?("WWW VFI Track Reports") &&
    (user.company.master? || user.company.system_code=='JJILL') &&
    user.view_shipments?
  end

  def self.run_report run_by, settings={}
    self.new.run run_by, settings
  end

  def initialize
    @cdefs ||= self.class.prep_custom_definitions [:ord_original_gac_date]
  end

  def run run_by, settings
    wb = Spreadsheet::Workbook.new

    # Yes, this handles leap years correctly
    start_date = Time.zone.now.in_time_zone("GMT").to_date - 1.year

    sheet_setup = sheet_setups
    sheet_setup.each {|k,v| sheet_from_query wb, k, v}
    workbook_to_tempfile wb, 'JJillWeeklyFreightSummary-'
  end

  private

  def sheet_setups
    # Yes, this handles leap years correctly
    start_date = Time.zone.now.in_time_zone("GMT").to_date - 1.year

    sheet_setup = {
      "PO Acknowledgement" => {query: po_ack_qry},
      "PO Integrity" => {query: po_integrity_qry},
      "Booking Exception" => {query: booking_exception_qry},
      "Transit Time" => {query: transit_time_qry},
      "Value In Transit" => {query: value_in_transit_qry},
      "Booking Integrity" => {query: booking_integrity_qry(start_date)},
      "Order Fulfillment" => order_fulfillment_setup(start_date)
    }
  end

  def sheet_from_query workbook, name, setup
    s = workbook.create_worksheet :name=>name
    table_from_query s, setup[:query], setup[:conversions], query_column_offset: setup[:query_column_offset], translations_modify_result_set: setup[:translations_modify_result_set]
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
AND DATEDIFF(now(),orders.last_revised_date) >= 7
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
    (orders.mode = 'Air' AND (DATEDIFF(orders.first_expected_delivery_date,orders.ship_window_end) <= 7 OR DATEDIFF(orders.first_expected_delivery_date,orders.ship_window_end) >= 10))
    OR
    (orders.mode = 'Ocean' AND (DATEDIFF(orders.first_expected_delivery_date,orders.ship_window_end) <= 32 OR DATEDIFF(orders.first_expected_delivery_date,orders.ship_window_end) >= 45))
  )
  AND
  (orders.ship_window_start >= now() AND orders.ship_window_end >= now())
GROUP BY orders.id
QRY
    q
  end
  def booking_exception_qry
    q = <<-SQL
      SELECT `PO`, `Vendor Style`, `Agent`, `Vendor`, `Ship Window End`
      FROM (
        SELECT
          orders.customer_order_number AS 'PO',
          GROUP_CONCAT(DISTINCT (select string_value 
                                from custom_values 
                                where custom_definition_id = (select id 
                                                              from custom_definitions 
                                                              where label = 'Vendor Style' 
                                                                and module_type = 'Product') 
                                                                and customizable_id = order_lines.product_id) SEPARATOR ', ') as 'Vendor Style',
          (SELECT name FROM companies WHERE companies.id = orders.agent_id) as 'Agent',
          (SELECT name FROM companies WHERE companies.id = orders.vendor_id) as 'Vendor',
          orders.ship_window_end as 'Ship Window End'
      FROM orders
        LEFT OUTER JOIN order_lines ON orders.id = order_lines.order_id
        LEFT OUTER JOIN booking_lines ON orders.id = booking_lines.order_id
      WHERE
        orders.closed_at is null
        AND orders.importer_id = (SELECT id FROM companies WHERE system_code = 'JJILL')
        AND (orders.approval_status = 'Accepted')
        AND DATEDIFF(orders.ship_window_end,now()) <= 14
        AND (orders.fob_point IN ('VN','PH','ID'))
        AND (booking_lines.id IS NULL)
        AND (orders.ship_window_end <= DATE_ADD(NOW(), INTERVAL 14 DAY))
      GROUP BY orders.id
      ) x
      SQL
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
and
shipments.canceled_date IS NULL
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
  (shipments.delivered_date IS NULL OR shipments.delivered_date > DATE_ADD(now(), INTERVAL -30 DAY))
  AND
  (shipments.cargo_on_hand_date IS NOT NULL)
  AND
  (shipments.canceled_date IS NULL)
  AND 
  (shipments.departure_date IS NOT NULL) 
  GROUP BY shipments.id, orders.id, order_lines.price_per_unit
QRY
    q
  end

  def booking_integrity_qry start_date
    # the q var is here primarily because my code formatter doesn't like not having it.
    q = <<QRY
SELECT
shipments.receipt_location as 'Origin',
shipments.booking_number as 'Booking #',
shipments.master_bill_of_lading as 'Master Bill #',
shipments.booking_mode as 'Booked Mode',
shipments.booking_shipment_type as 'Booked Load',
shipments.booking_carrier as 'Booked Carrier',
shipments.booking_vessel as 'Booked Vessel',
destination_port.name as 'Booked Destination',
shipments.booking_est_departure_date as 'Booked Origin ETD',
shipments.booking_est_arrival_date as 'Booked Destination ETA',
shipments.house_bill_of_lading as 'Actual Shipment #',
shipments.mode as 'Actual Mode',
shipments.shipment_type as 'Actual Load',
shipments.vessel_carrier_scac as 'Actual Carrier',
shipments.vessel as 'Actual Vessel',
destination_port.name as 'Actual Destination',
shipments.departure_date as 'Actual Departure',
shipments.arrival_port_date as 'Actual Arrival',
DATEDIFF(shipments.departure_date,shipments.booking_est_departure_date) as 'Departure Variance',
DATEDIFF(shipments.arrival_port_date,shipments.booking_est_arrival_date) as 'Arrival Variance',
shipments.delay_reason_codes as 'Shipment Note'
FROM
shipments
INNER JOIN ports as destination_port ON destination_port.id = shipments.destination_port_id
WHERE
shipments.importer_id = (SELECT id FROM companies WHERE system_code = 'JJILL')
AND shipments.arrival_port_date > ?
AND shipments.canceled_date IS NULL
ORDER BY shipments.arrival_port_date desc
QRY
    ActiveRecord::Base.sanitize_sql_array([q, start_date])
  end

  def order_fulfillment_setup start_date
    setup = {}
    setup[:query] = order_fulfillment_qry start_date
    setup[:query_column_offset] = 2
    setup[:translations_modify_result_set] = true
    conversions = {}

    # Order Quantity lookup
    conversions[7] = lambda do |result_set_row, raw_column_value|
      find_order_quantity result_set_row[0], result_set_row[1]
    end

    # Ship Qty vs. Booked Qty
    conversions[21] = lambda do |result_set_row, raw_column_value|
      quantity(result_set_row[15], result_set_row[11])
    end

    # Shipped Qty vs. Order Qty
    conversions[22] = lambda do |result_set_row, raw_column_value|
      quantity(result_set_row[15], result_set_row[7])
    end

    setup[:conversions] = conversions

    setup
  end

  def order_fulfillment_qry start_date
    q = <<QRY
select s.id 'Shipment ID', o.id 'Order ID', s.receipt_location 'Origin', vend.name 'Vendor', fact.name 'Factory', o.customer_order_number 'PO Number', o.mode 'PO Mode','' as 'PO Qty',
gac.date_value 'PO GAC', s.booking_number 'Booking #', s.booking_mode 'Booking Mode',
ifnull((select sum(bl.quantity) from booking_lines bl where bl.shipment_id = s.id and bl.order_id = o.id), 0) 'Booked Qty',
s.booking_cutoff_date 'Booking Cut Off', s.house_bill_of_lading 'Shipment #', s.mode 'Ship Mode',
sum(ps.quantity) "Shipped Qty", s.shipment_cutoff_date 'Shipment Cutoff', s.cargo_on_hand_date 'FCR Date',
DATEDIFF(s.cargo_on_hand_date, s.shipment_cutoff_date) 'FCR vs. Ship Cutoff',
DATEDIFF(s.cargo_on_hand_date, s.booking_cutoff_date) 'FCR vs. Book Cutoff',
DATEDIFF(s.cargo_on_hand_date, gac.date_value) 'FCR vs. GAC',
'' as "Shipped Qty vs. Booked Qty",
'' as "Shipped Qty vs. Ordered Qty"
from shipments s
inner join shipment_lines sl on s.id = sl.shipment_id
inner join piece_sets ps on sl.id = ps.shipment_line_id
inner join order_lines ol on ps.order_line_id = ol.id
inner join orders o on ol.order_id= o.id
inner join companies imp on s.importer_id = imp.id and imp.system_code = 'JJILL' and imp.importer = true
left outer join companies vend on o.vendor_id = vend.id
left outer join companies fact on o.factory_id = fact.id
LEFT OUTER JOIN custom_values gac ON gac.custom_definition_id = #{@cdefs[:ord_original_gac_date].id.to_i} and gac.customizable_id = o.id and gac.customizable_type = 'Order'
where s.arrival_port_date > ?
and s.canceled_date IS NULL
group by s.id, o.id
order by s.arrival_port_date desc
QRY
    ActiveRecord::Base.sanitize_sql_array([q, start_date])
  end

  def find_order_quantity shipment_id, order_id
    qry = <<QRY
SELECT sum(ol.quantity)
FROM order_lines ol
INNER JOIN (
  SELECT DISTINCT ps.order_line_id
  FROM piece_sets ps
  INNER JOIN order_lines inner_ol ON ps.order_line_id = inner_ol.id
  INNER JOIN shipment_lines sl on ps.shipment_line_id = sl.id
  WHERE inner_ol.order_id = ? AND sl.shipment_id = ?) l ON l.order_line_id = ol.id
QRY
    qry = ActiveRecord::Base.sanitize_sql_array([qry, order_id, shipment_id])
    result = ActiveRecord::Base.connection.execute qry

    qty = result.first.first
    qty ? qty : 0
  end

  def quantity qty1, qty2
    qty1 = qty1.presence || 0
    qty2 = qty2.presence || 0

    BigDecimal.new(qty1 - qty2)
  end
end; end; end
