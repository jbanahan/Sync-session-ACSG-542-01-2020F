require 'open_chain/report/report_helper'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module Report; class AscenaEntryAuditReport
  include OpenChain::Report::ReportHelper
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def self.permission? user
    (MasterSetup.get.system_code == "www-vfitrack-net" || Rails.env.development?) && 
      (user.view_entries? && (user.company.master? || user.company.system_code == "ASCENA" || linked_to_ascena?(user.company)))
  end

  def self.linked_to_ascena? co
    ascena = Company.where(system_code: "ASCENA").first
    return false unless ascena
    co.linked_companies.to_a.include? ascena
  end

  def self.run_report run_by, settings={}
    self.new.run run_by, settings
  end

  def run run_by, settings
    start_date = sanitize_date_string settings['start_date'], run_by.time_zone
    end_date = sanitize_date_string settings['end_date'], run_by.time_zone
    wb = create_workbook start_date, end_date, run_by.time_zone
    workbook_to_tempfile wb, 'AscenaEntryAuditReport-', file_name: "Ascena Entry Audit Report.xls"
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions [:ord_selling_agent, :ord_type]
  end

  def create_workbook start_date, end_date, time_zone
    wb, sheet = XlsMaker.create_workbook_and_sheet "Ascena Entry Audit Report"
    table_from_query sheet, query(start_date, end_date, cdefs), conversions(time_zone)
    wb
  end

  def conversions time_zone
    {"First Release Date" => datetime_translation_lambda(time_zone), 
     "First Summary Sent Date" => datetime_translation_lambda(time_zone), 
     "Entry Filed Date" => datetime_translation_lambda(time_zone), 
     "Release Date" => datetime_translation_lambda(time_zone) }
  end

  def query start_date, end_date, cdefs
    <<-SQL
      SELECT e.broker_reference AS 'Broker Reference',
             e.entry_number AS 'Entry Number',
             e.entry_type AS 'Entry Type',
             e.first_release_date AS 'First Release Date',
             e.first_entry_sent_date AS 'First Summary Sent Date',
             e.entry_filed_date AS 'Entry Filed Date',
             e.final_statement_date AS 'Final Statement Date',
             e.release_date AS 'Release Date',
             e.transport_mode_code AS 'Mode of Transport',
             e.master_bills_of_lading AS 'Master Bills',
             e.house_bills_of_lading AS 'House Bills',
             e.unlading_port_code AS 'Port of Unlading Code', 
             (CASE e.source_system WHEN 'Fenix' 
                THEN (SELECT name FROM ports WHERE ports.cbsa_port = e.entry_port_code) 
                ELSE (SELECT name FROM ports WHERE ports.schedule_d_code = e.entry_port_code) END) AS 'Port of Entry Name',
             e.lading_port_code AS 'Port of Lading Code',
             cil.po_number AS 'PO Number',
             cil.product_line AS 'Product Line',
             cil.part_number AS 'Part Number',
             e.importer_tax_id AS 'Importer Tax ID',
             e.customer_name AS 'Customer Name',
             ci.invoice_number AS 'Invoice Number',
             cil.country_origin_code AS 'Country Origin Code',
             cil.country_export_code AS 'Country Export Code',
             cil.department AS 'Department',
             cit.hts_code AS 'HTS Code',
             cit.duty_rate AS 'Duty Rate',
             cil.mid AS 'MID',
             vend.name AS 'Vendor Name',
             vend.system_code AS 'Vendor Number',
             IF(ord_type.string_value = "NONAGS", "", ord_agent.string_value) AS 'AGS Office',
             cil.subheader_number AS 'Subheader Number',
             cil.line_number AS 'Line Number',
             cil.customs_line_number AS 'Customs Line Number',
             cil.quantity AS 'Units',
             cil.unit_of_measure AS 'UOM',
             cit.spi_primary AS 'SPI - Primary',
             cit.classification_qty_1 AS 'Quantity 1',
             cit.classification_qty_2 AS 'Quantity 2',
             cit.classification_uom_1 AS 'UOM 1',
             cit.classification_uom_2 AS 'UOM 2',
             cil.add_case_number AS 'ADD Case Number',
             cil.value AS 'Value',
             ci.invoice_value AS 'Invoice Value',
             cit.entered_value AS 'Entered Value',
             (SELECT IFNULL(SUM(total_duty_t.duty_amount), 0) 
              FROM commercial_invoice_tariffs total_duty_t
              WHERE total_duty_t.commercial_invoice_line_id = cil.id) AS 'Total Duty',
             cil.prorated_mpf AS 'MPF - Prorated',
             cil.mpf AS 'MPF - Full',
             cil.hmf AS 'HMF',
             (SELECT IFNULL(total_fees_l.prorated_mpf, 0) + IFNULL(total_fees_l.hmf, 0) + IFNULL(total_fees_l.cotton_fee, 0) 
              FROM commercial_invoice_lines total_fees_l
              WHERE total_fees_l.id = cil.id) AS 'Total Fees',
             cil.add_case_value AS 'ADD Value',
             cil.cvd_case_value AS 'CVD Value',
             cit.excise_amount AS 'Excise Amount',
             cil.cotton_fee AS 'Cotton Fee',          
             (SELECT IFNULL(total_duty_fees_l.prorated_mpf, 0) + IFNULL(total_duty_fees_l.hmf, 0) + IFNULL(total_duty_fees_l.cotton_fee, 0) +
                (SELECT IFNULL(SUM(total_duty_fees_t.duty_amount), 0)
                 FROM commercial_invoice_tariffs total_duty_fees_t
                 WHERE total_duty_fees_t.commercial_invoice_line_id = cil.id)
              FROM commercial_invoice_lines total_duty_fees_l
              WHERE total_duty_fees_l.id = cil.id) AS 'Total Duty + Fees',
             ci.non_dutiable_amount AS 'Inv Non-Dutiable Amount',
             cil.non_dutiable_amount AS 'Inv Ln Non-Dutiable Amount',
             e.total_non_dutiable_amount AS 'Total Non-Dutiable Amount',
             cil.unit_price AS 'Price to Brand',
             IF(ord_type.string_value = "NONAGS", 0, ol.price_per_unit) AS 'Vendor Price to AGS',
             IF((ord_type.string_value = "NONAGS" OR cil.contract_amount <= 0), 0, cit.entered_value / cil.quantity) AS 'First Sale Price',
             (SELECT IF((SUM(t.entered_value) = 0) OR ROUND((SUM(t.duty_amount)/SUM(t.entered_value))*(l.value - SUM(t.entered_value)),2)< 1,0,ROUND((SUM(t.duty_amount)/SUM(t.entered_value))*(l.value - SUM(t.entered_value)),2))
              FROM commercial_invoice_lines l
              INNER JOIN commercial_invoice_tariffs t ON l.id = t.commercial_invoice_line_id 
              WHERE l.id = cil.id) AS 'First Sale Duty Savings',
             IF(cil.contract_amount > 0, 'Y', 'N') AS 'First Sale Flag'
      FROM entries e
        INNER JOIN commercial_invoices ci ON e.id = ci.entry_id
        INNER JOIN commercial_invoice_lines cil ON ci.id = cil.commercial_invoice_id
        INNER JOIN commercial_invoice_tariffs cit ON cil.id = cit.commercial_invoice_line_id
        LEFT OUTER JOIN orders o ON o.order_number = CONCAT("ASCENA-", cil.po_number)
        LEFT OUTER JOIN order_lines ol ON o.id = ol.order_id
        LEFT OUTER JOIN products p on ol.product_id = p.id AND p.unique_identifier = CONCAT("ASCENA-", cil.part_number)
        LEFT OUTER JOIN custom_values ord_type ON ord_type.customizable_id = o.id AND ord_type.customizable_type = "Order" AND ord_type.custom_definition_id = #{cdefs[:ord_type].id}
        LEFT OUTER JOIN custom_values ord_agent ON ord_agent.customizable_id = o.id AND ord_agent.customizable_type = "Order" AND ord_agent.custom_definition_id = #{cdefs[:ord_selling_agent].id}
        INNER JOIN companies vend ON vend.id = o.vendor_id
      WHERE e.release_date >= '#{start_date}' AND e.release_date < '#{end_date}'
        AND e.customer_number = "ASCE"
    SQL
  end
end; end; end