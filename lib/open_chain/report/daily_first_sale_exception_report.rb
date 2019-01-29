require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module Report; class DailyFirstSaleExceptionReport
  include OpenChain::Report::ReportHelper
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  ALLIANCE_CUSTOMER_NUMBER ||= "ASCE"

  def self.permission? user
    ascena = Company.importers.where(alliance_customer_number: ALLIANCE_CUSTOMER_NUMBER).first
    return false unless ascena

    (MasterSetup.get.system_code == "www-vfitrack-net" || Rails.env.development?) && 
    (user.view_entries? && (user.company.master? || ascena.can_view?(user)))
  end

  def self.run_report run_by, settings={}
    self.new.run run_by, settings
  end

  def self.run_schedulable settings={}
    self.new.send_email(settings['email'])
  end

  def self.get_mid_vendors
    DataCrossReference.get_all_pairs("asce_mid").keys
  end
  
  def run run_by, settings
    wb = create_workbook run_by.time_zone
    workbook_to_tempfile wb, 'DailyFirstSaleException-', file_name: "Daily First Sale Exception Report.xls"
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions [:ord_selling_agent, :ord_type]
  end

  def send_email email
    wb = create_workbook "Eastern Time (US & Canada)"
    workbook_to_tempfile wb, 'DailyFirstSaleException-', file_name: 'Daily First Sale Exception Report.xls' do |t|
      subject = "Daily First Sale Exception Report"
      body = "<p>Report attached.<br>--This is an automated message, please do not reply.<br>This message was generated from VFI Track</p>".html_safe
      OpenMailer.send_simple_html(email, subject, body, t).deliver!
    end
  end

  def create_workbook time_zone
    wb, sheet = XlsMaker.create_workbook_and_sheet "Daily First Sale Exception Report"
    table_from_query sheet, query(self.class.get_mid_vendors, cdefs), conversions(time_zone)
    wb
  end

  def conversions(time_zone)
    {"Release Date" => datetime_translation_lambda(time_zone)}
  end

  def query mid_list, cdefs
    <<-SQL
      SELECT e.entry_number AS "Entry#", 
             e.release_date AS "Release Date", 
             e.entry_filed_date AS "Entry Filed Date",
             e.duty_due_date AS "Duty Due Date", 
             e.master_bills_of_lading AS "Master Bills", 
             e.house_bills_of_lading AS "House Bills", 
             cil.po_number AS "PO#",
             cil.product_line AS 'Brand',
             cil.part_number AS 'Item#',
             ci.invoice_number AS 'Invoice#',
             cil.country_origin_code AS 'COO',
             cil.department AS 'Department',
             cit.hts_code AS 'HTS',
             cit.duty_rate * 100 AS 'Duty Rate',
             cil.mid AS 'MID',
             cil.vendor_name AS 'Supplier',
             vend.name AS 'Vendor Name',
             vend.system_code AS 'Vendor Number',
             IF(ord_type.string_value = "NONAGS", "", ord_agent.string_value) AS 'AGS Office',
             cil.quantity AS 'Item Quantity',
             cil.unit_of_measure AS 'Item UOM',
             cil.value AS 'Value',
             ci.invoice_value AS 'Invoice Value',
             cit.entered_value AS 'Entered Value',
             cit.duty_amount AS 'Duty',
             cil.non_dutiable_amount AS 'NDC',
             cil.unit_price AS 'Price to Brand',
             IF(ord_type.string_value = "NONAGS", 0, (SELECT ordln.price_per_unit
                                                      FROM order_lines ordln
                                                        INNER JOIN products prod ON prod.id = ordln.product_id                                                                                    
                                                      WHERE ordln.order_id = o.id AND prod.unique_identifier = CONCAT("ASCENA-", cil.part_number) 
                                                      LIMIT 1)) AS 'Vendor Price to AGS',
             IF((ord_type.string_value = "NONAGS" OR cil.contract_amount <= 0), 0, cit.entered_value / cil.quantity) AS 'First Sale Price'
      FROM entries e
        INNER JOIN commercial_invoices ci ON ci.entry_id = e.id
        INNER JOIN commercial_invoice_lines cil ON ci.id = cil.commercial_invoice_id
        INNER JOIN commercial_invoice_tariffs cit ON cil.id = cit.commercial_invoice_line_id
        INNER JOIN countries c on e.import_country_id = c.id and c.iso_code = 'US'
        LEFT OUTER JOIN orders o ON o.order_number = CONCAT("ASCENA-", cil.product_line, '-', cil.po_number)
        LEFT OUTER JOIN custom_values ord_type ON ord_type.customizable_id = o.id AND ord_type.customizable_type = "Order" AND ord_type.custom_definition_id = #{cdefs[:ord_type].id}
        LEFT OUTER JOIN custom_values ord_agent ON ord_agent.customizable_id = o.id AND ord_agent.customizable_type = "Order" AND ord_agent.custom_definition_id = #{cdefs[:ord_selling_agent].id}
        INNER JOIN companies vend ON vend.id = o.vendor_id
      WHERE e.customer_number = "#{ALLIANCE_CUSTOMER_NUMBER}"
        AND e.first_entry_sent_date IS NOT NULL
        AND e.duty_due_date >= NOW()
        AND (cil.contract_amount = 0 OR cil.contract_amount IS NULL)
        AND (cit.entered_value = cil.value)
        AND CONCAT(cil.mid,"-",vend.system_code) in (#{format_mids(mid_list)})
      ORDER BY e.entry_filed_date
    SQL
  end

  private

  def format_mids mid_list
    mids = mid_list.map{|m| ActiveRecord::Base.sanitize m}.join(",")
    mids.blank? ? "''" : mids
  end


end; end; end;