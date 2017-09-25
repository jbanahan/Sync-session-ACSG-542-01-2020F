require 'open_chain/report/report_helper'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/custom_handler/ascena/ascena_report_helper'

module OpenChain; module Report; class AscenaEntryAuditReport
  include OpenChain::Report::ReportHelper
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include OpenChain::CustomHandler::Ascena::AscenaReportHelper

  def self.permission? user
    (MasterSetup.get.system_code == "www-vfitrack-net" || Rails.env.development?) && 
      (user.view_entries? && (user.company.master? || user.company.system_code == SYSTEM_CODE || linked_to_ascena?(user.company)))
  end

  def self.run_report run_by, settings={}
    self.new.run run_by, settings
  end

  def run run_by, settings
    start_date, end_date = get_dates run_by, settings
    wb = create_workbook start_date, end_date, settings['range_field'], run_by.time_zone, settings['run_as_company']
    workbook_to_tempfile wb, 'AscenaEntryAuditReport-', file_name: "Ascena Entry Audit Report.xls"
  end

  def get_dates run_by, settings
    if settings['range_field'] == 'first_release_date'
      start_date, end_date = release_date_dates(settings['start_release_date'], settings['end_release_date'], run_by.time_zone)
    elsif settings['range_field'] == 'fiscal_date'
      start_date, end_date = fiscal_month_dates(*settings['start_fiscal_year_month'].split('-'), *settings['end_fiscal_year_month'].split('-'))
    end
    [start_date, end_date]
  end

  def release_date_dates start_date, end_date, time_zone
    start_date = sanitize_date_string start_date, time_zone
    end_date = sanitize_date_string end_date, time_zone
    [start_date, end_date]
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions [:ord_selling_agent, :ord_type, :ord_line_wholesale_unit_price, :prod_reference_number]
  end

  def create_workbook start_date, end_date, range_field, time_zone, importer_system_code
    wb, sheet = XlsMaker.create_workbook_and_sheet "Ascena Entry Audit Report"
    table_from_query sheet, query(start_date, end_date, range_field, importer_system_code, cdefs), conversions(time_zone).merge("Web Link"=>weblink_translation_lambda(CoreModule::ENTRY))
    wb
  end

  def conversions time_zone
    {"First Release Date" => datetime_translation_lambda(time_zone), 
     "First Summary Sent Date" => datetime_translation_lambda(time_zone), 
     "Entry Filed Date" => datetime_translation_lambda(time_zone), 
     "Release Date" => datetime_translation_lambda(time_zone) }
  end

  def query start_date, end_date, range_field, importer_system_code, cdefs
    <<-SQL
      SELECT e.broker_reference AS 'Broker Reference',
             e.entry_number AS 'Entry Number',
             e.entry_type AS 'Entry Type',
             e.first_release_date AS 'First Release Date',
             e.first_entry_sent_date AS 'First Summary Sent Date',
             e.entry_filed_date AS 'Entry Filed Date',
             e.final_statement_date AS 'Final Statement Date',
             e.release_date AS 'Release Date',
             e.duty_due_date AS 'Duty Due Date',
             e.transport_mode_code AS 'Mode of Transport',
             e.master_bills_of_lading AS 'Master Bills',
             e.house_bills_of_lading AS 'House Bills',
             e.unlading_port_code AS 'Port of Unlading Code', 
             (CASE e.source_system WHEN 'Fenix' 
                THEN (SELECT name FROM ports WHERE ports.cbsa_port = e.entry_port_code) 
                ELSE (SELECT name FROM ports WHERE ports.schedule_d_code = e.entry_port_code) END) AS 'Port of Entry Name',
             e.lading_port_code AS 'Port of Lading Code',
             (SELECT COUNT(*) FROM containers WHERE containers.entry_id = e.id) AS 'Container Count',
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
             fact.name AS 'MID Supplier Name',
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
             #{invoice_value_brand('o', 'cil', cdefs[:ord_line_wholesale_unit_price].id, cdefs[:prod_reference_number].id, importer_system_code)} AS 'Invoice Value - Brand',
             #{invoice_value_7501('cil')} AS 'Invoice Value - 7501',
             #{invoice_value_contract('cil')} AS 'Invoice Value - Contract',
             cit.entered_value AS 'Entered Value',
             #{rounded_entered_value('cit')} AS 'Rounded Entered Value',
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
             #{unit_price_brand('o', 'cil', cdefs[:ord_line_wholesale_unit_price].id, cdefs[:prod_reference_number].id, importer_system_code)} AS 'Unit Price - Brand',
             #{unit_price_po('o', 'cil', cdefs[:prod_reference_number].id, importer_system_code)} AS 'Unit Price - PO',
             #{unit_price_7501('cil')} AS 'Unit Price - 7501',
             (SELECT IF((SUM(t.entered_value) = 0) OR ROUND((SUM(t.duty_amount)/SUM(t.entered_value))*(l.value - SUM(t.entered_value)),2)< 1,0,ROUND((SUM(t.duty_amount)/SUM(t.entered_value))*(l.value - SUM(t.entered_value)),2))
              FROM commercial_invoice_lines l
              INNER JOIN commercial_invoice_tariffs t ON l.id = t.commercial_invoice_line_id 
              WHERE l.id = cil.id) AS 'Duty Savings - NDC',
             #{duty_savings_first_sale('cil')} AS 'Duty Savings - First Sale',
             IF(cil.contract_amount > 0, 'Y', 'N') AS 'First Sale Flag',
             IF(cil.related_parties, 'Y', 'N') AS 'Related Parties', 
             e.fiscal_month AS 'Fiscal Month', 
             e.fiscal_year AS 'Fiscal Year',  
             e.id AS 'Web Link'
      FROM entries e
        INNER JOIN commercial_invoices ci ON e.id = ci.entry_id
        INNER JOIN commercial_invoice_lines cil ON ci.id = cil.commercial_invoice_id
        INNER JOIN commercial_invoice_tariffs cit ON cil.id = cit.commercial_invoice_line_id
        LEFT OUTER JOIN orders o ON o.order_number = CONCAT("#{importer_system_code}-", cil.po_number)
        LEFT OUTER JOIN custom_values ord_type ON ord_type.customizable_id = o.id AND ord_type.customizable_type = "Order" AND ord_type.custom_definition_id = #{cdefs[:ord_type].id}
        LEFT OUTER JOIN custom_values ord_agent ON ord_agent.customizable_id = o.id AND ord_agent.customizable_type = "Order" AND ord_agent.custom_definition_id = #{cdefs[:ord_selling_agent].id}
        LEFT OUTER JOIN companies fact ON fact.id = o.factory_id
        LEFT OUTER JOIN companies vend ON vend.id = o.vendor_id
      WHERE e.#{range_field} >= '#{start_date}' AND e.#{range_field} < '#{end_date}'
        AND e.customer_number = "#{importer_system_code == SYSTEM_CODE ? 'ASCE' : 'ATAYLOR'}"
    SQL
  end
end; end; end