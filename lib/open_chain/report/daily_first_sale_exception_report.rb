module OpenChain; module Report; class DailyFirstSaleExceptionReport
  include OpenChain::Report::ReportHelper

  ALLIANCE_CUSTOMER_NUMBER = "ASCE"

  def initialize
    @import_country ||= self.class.get_country
    @importer ||= self.class.get_importer
  end

  def self.permission? user
    imp = get_importer
    (MasterSetup.get.system_code == "www-vfitrack-net" || Rails.env.development?) && 
    (user.view_entries? && (user.company.master? || imp.can_view?(user)))
  end

  def self.run_report run_by, settings={}
    self.new.run run_by, settings
  end

  def self.run_schedulable settings={}
    self.new.send_email(settings['email'])
  end

  def self.get_importer
    importer = Company.importers.where(alliance_customer_number: ALLIANCE_CUSTOMER_NUMBER).first
    raise "Unable to find importer account with alliance_customer_number '#{ALLIANCE_CUSTOMER_NUMBER}'" unless importer
    importer
  end

  def self.get_country
    country = Country.where(iso_code: 'US').first
    raise "Unable to find country with iso_code 'US'" unless country
    country
  end

  def self.get_mids
    #ensures query's IN clause receives string input even with empty list
    DataCrossReference.get_all_pairs("asce_mid").keys.presence || ""
  end
  
  def run run_by, settings
    wb = create_workbook run_by.time_zone
    workbook_to_tempfile wb, 'DailyFirstSaleException-', file_name: "Daily First Sale Exception Report.xls"
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
    table_from_query sheet, query(self.class.get_mids), conversions(time_zone)
    wb
  end

  def conversions(time_zone)
    {"Release Date" => datetime_translation_lambda(time_zone)}
  end

  def query mid_list
    <<-SQL
      SELECT e.entry_number AS "Entry#", 
             e.release_date AS "Release Date", 
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
             cil.quantity AS 'Item Quantity',
             cil.unit_of_measure AS 'Item UOM',
             cil.value AS 'Invoice Value',
             cit.entered_value AS 'Entered Value',
             cit.duty_amount AS 'Duty',
             cil.prorated_mpf AS 'Prorated MPF',
             cil.hmf AS 'HMF',
             cil.cotton_fee AS 'Cotton Fee',
             cil.non_dutiable_amount AS 'NDC'
      FROM entries e
        INNER JOIN commercial_invoices ci ON ci.entry_id = e.id
        INNER JOIN commercial_invoice_lines cil ON ci.id = cil.commercial_invoice_id
        INNER JOIN commercial_invoice_tariffs cit ON cil.id = cit.commercial_invoice_line_id
      WHERE e.import_country_id = #{@import_country.id}
        AND e.customer_number = "#{ALLIANCE_CUSTOMER_NUMBER}"
        AND e.release_date IS NOT NULL
        AND e.duty_due_date <= NOW()
        AND (cil.contract_amount = 0 OR cil.contract_amount IS NULL)
        AND (cit.entered_value = cil.value)
        AND cil.mid in (#{mid_list.map{|m| ActiveRecord::Base.sanitize m}.join(",")})
    SQL
  end
end; end; end;