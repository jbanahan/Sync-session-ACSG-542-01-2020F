require 'open_chain/report/builder_output_report_helper'

module OpenChain; module Report; class UsBillingSummary
  include OpenChain::Report::BuilderOutputReportHelper
    def self.permission? user
      (MasterSetup.get.custom_feature?("WWW") || Rails.env.development?) && user.company.master? && user.view_broker_invoices?
    end

    def self.run_report run_by, settings={}
      self.new.run run_by, settings
    end

    def run run_by, settings
      safe_settings = sanitize(settings)
      qry = query(safe_settings['customer_number'], safe_settings['start_date'], safe_settings['end_date'])
      wb = XlsxBuilder.new
      sheet = wb.create_sheet("Billing Summary")
      # Translate the release, arrival date into Eastern Timezone before trimming the time portion off
      # Moved out of the query because if done in the query we're converting the UTC time to a date and potentially 
      # reporting the wrong date if the release is done between 8-12PM EDT.
      dt_lambda = datetime_translation_lambda("Eastern Time (US & Canada)", true)
      conversions = {"Release" => dt_lambda, "Arrival" => dt_lambda}
      write_query_results_to_tempfile wb, sheet, qry, base_filename(settings['customer_number']), data_conversions: conversions
    end

    def base_filename customer_number
      today = Time.zone.now.in_time_zone("America/New_York").to_date.strftime("%Y-%m-%d")
      "USBillingSummary_#{customer_number}_#{today}"
    end

    def sanitize settings
      {'start_date' => sanitize_date_string(settings['start_date']),
       'end_date' => sanitize_date_string(settings['end_date']),
       'customer_number' => ActiveRecord::Base.sanitize(settings['customer_number'])}
    end

    def query cust_num, start_date, end_date
      <<-SQL
        SELECT 
          ent.entry_number AS "Entry Number", 
          ent.arrival_date AS "Arrival", 
          ent.release_date AS "Release", 
          ent.entry_port_code AS "Entry Port", 
          ent.broker_reference AS "File Number", 
          ent.customer_name AS "Customer Name", 
          ent.export_date AS "Export Date", 
          ent.master_bills_of_lading AS "MBOLs", 
          ent.house_bills_of_lading AS "HBOLs", 
          ci.mfid AS "MID", 
          ci.vendor_name AS "Vendor", 
          cil.line_number AS "Invoice Line", 
          ci.invoice_number AS "Commercial Invoice Number", 
          cit.tariff_description AS "Item Description", 
          cit.hts_code AS "HTS Code", 
          cit.gross_weight AS "Gross Weight",
          cil.quantity AS "Invoice Quantity", 
          cil.unit_of_measure AS "Invoice UOM", 
          cit.classification_qty_1 AS "Tariff Quantity", 
          cit.classification_uom_1 AS "Tariff UOM", 
          cit.entered_value AS "Entered Value", 
          cil.value AS "Invoice Value", 
          cit.duty_amount AS "Duty Amount", 
          cit.duty_rate AS "Duty Rate", 
          cil.cotton_fee AS "Cotton Fee", 
          cil.hmf AS "HMF", 
          cil.mpf AS "MPF", 
          cil.department AS "Department", 
          cil.po_number AS "PO Number", 
          cil.part_number AS "Style", 
          CONCAT(ent.broker_reference, bi.suffix) AS "Invoice Number", 
          bi.invoice_total AS "Invoice Total", 
          ((bi.invoice_total/ent.total_units)*cil.quantity) AS "Entry Fee Per Line", 
          ent.total_packages AS "Total Packages",
          ent.container_numbers AS "Containers"
        FROM broker_invoices bi
          INNER JOIN entries ent ON bi.entry_id = ent.id
          INNER JOIN commercial_invoices ci ON ent.id = ci.entry_id
          INNER JOIN commercial_invoice_lines cil ON ci.id = cil.commercial_invoice_id
          INNER JOIN commercial_invoice_tariffs cit ON cit.commercial_invoice_line_id = cil.id
        WHERE bi.customer_number = #{cust_num} AND bi.invoice_date BETWEEN "#{start_date}" AND "#{end_date}"
      SQL
    end

end; end; end
