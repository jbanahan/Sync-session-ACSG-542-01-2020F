require 'open_chain/report/report_helper'

module OpenChain; module Report; class NexeoOceanExportsReport
  extend OpenChain::Report::ReportHelper

  def self.run_schedulable opts = {}
    raise "You must include at least one email in the email_to scheduled job parameter." if opts['email_to'].blank?

    start_date = (now - 1.month).at_beginning_of_month
    end_date = (now - 1.month).at_end_of_month + 1.day

    f = run_report(User.integration, start_date: start_date.to_s, end_date: end_date.to_s)
    OpenMailer.send_simple_html(opts['email_to'], "Nexeo Exports for #{start_date.strftime("%b")}", "Attached is the Nexeo Export shipment report for #{start_date.strftime("%B")}.", f).deliver_now

  end

  def self.now
    # In it's own method purely for testing reasons
    Time.zone.now
  end

  def self.permission? user
    nexeo_company = nexeo
    Rails.env.development? || (user.view_shipments? && nexeo_company && nexeo_company.can_view?(user))
  end

  def self.nexeo
    Company.importers.where(alliance_customer_number: "NEXEO").first
  end

  def self.run_report run_by, settings = {}
    start_date, end_date = dates(settings.with_indifferent_access)
    filename = "Exports #{start_date.strftime("%m-%d-%Y")} - #{end_date.strftime("%m-%d-%Y")}"

    headers = ["Consignee", "PO Number of Shipment Reference Number", "Shipping Number", "Vessel / Voyage", "Pick Up Location", "Port Of Loading", "ETD", "Port of Discharge", "Place of Delivery", "Container Number", "Size Type", "HBL", "Carrier", "MBL", "Freight", "Total", "Weight LBs"]
    wb, sheet = XlsMaker.create_workbook_and_sheet filename
    translations = {
      "Weight LBs" => convert_to_lbs_translation,
      "Size Type" => lcl_container_translation,
      "MBL" => master_bill_translation
    }
    table_from_query sheet, query(start_date, end_date), translations, column_names: headers
    workbook_to_tempfile wb, filename, file_name: "#{filename}.xls"
  end

  def self.query start_date, end_date
    # The PO and Container subselects are there so we only show a single row per shipment (there aren't supposed to be multiple PO or Containers per shipment for Nexeo)
    <<-QRY
SELECT b.name,
(SELECT po.customer_order_number FROM shipment_lines sl inner join piece_sets ps ON ps.shipment_line_id = sl.id inner join order_lines ol ON ol.id = ps.order_line_id INNER JOIN orders po ON po.id = ol.order_id WHERE s.id = sl.shipment_id LIMIT 1),
s.importer_reference, concat(ifnull(s.vessel, ''), ' V. ', ifnull(s.voyage, '')), '', p.name, s.est_departure_date, dis.body, fin.body, 
(SELECT con.container_number FROM containers con WHERE con.shipment_id = s.id LIMIT 1),
s.lcl, s.house_bill_of_lading, car.value, concat(ifnull(s.booking_carrier, ''), ifnull(s.master_bill_of_lading, '')), s.freight_total, s.invoice_total, s.gross_weight
FROM shipments s
LEFT OUTER JOIN addresses b on b.id = s.buyer_address_id
LEFT OUTER JOIN comments dis on dis.commentable_id = s.id and dis.commentable_type = 'Shipment' and dis.subject = 'Discharge Port'
LEFT OUTER JOIN comments fin on fin.commentable_id = s.id and fin.commentable_type = 'Shipment' and fin.subject = 'Final Destination'
LEFT OUTER JOIN ports p on s.lading_port_id = p.id
LEFT OUTER JOIN containers c on s.id = c.shipment_id
LEFT OUTER JOIN data_cross_references car ON car.cross_reference_type = '#{DataCrossReference::EXPORT_CARRIER}' AND car.`key` = s.booking_carrier
WHERE s.est_departure_date >= '#{start_date.strftime("%Y-%m-%d")}' AND s.est_departure_date < '#{end_date.strftime("%Y-%m-%d")}' and s.importer_id = #{nexeo.id}
ORDER BY s.est_departure_date asc
QRY
  end

  def self.dates settings = {}
    [Time.zone.parse(settings[:start_date]).to_date, Time.zone.parse(settings[:end_date]).to_date]
  end

  def self.convert_to_lbs_translation
    lambda do |rs, val| 
      val.nil? ? 0 : (BigDecimal(val) * BigDecimal("2.20462")).round(0, BigDecimal::ROUND_HALF_UP).to_i
    end
  end

  def self.lcl_container_translation
    lambda do |rs, val|
      # Container size is not given in data from export system, so we leave blank
      lcl?(rs) ? "LCL" : ""
    end
  end

  def self.master_bill_translation
    lambda do |rs, val|
      lcl?(rs) ? "COLOAD" : val
    end
  end

  def self.lcl? rs
    rs[10].to_s.to_boolean
  end

end; end; end