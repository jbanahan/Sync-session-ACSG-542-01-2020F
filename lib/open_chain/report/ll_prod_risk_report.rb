require 'open_chain/report/report_helper'
module OpenChain
  module Report
    class LlProdRiskReport
      include OpenChain::Report::ReportHelper
      
      def self.permission? user
        user.view_products? && user.company.master? && MasterSetup.get.system_code=='ll'
      end

      def self.run_report(user, settings = {})
        self.new.run
      end

      def self.run_schedulable opts_hash={}
        self.new.send_email('email' => opts_hash['email'])
      end

      def create_workbook
        wb = XlsMaker.create_workbook "Products Needing Risk Assignment"
        table_from_query wb.worksheet(0), query, {'Vendor SAP #' => link_lambda} 
        wb
      end

      def link_lambda
        lambda do |result_set_row, raw_column_value| 
          vendor_sap, vendor_id = raw_column_value.split("/")
          vendor_sap_link = XlsMaker.excel_url("/vendors/" + vendor_id)
          XlsMaker.create_link_cell(vendor_sap_link, vendor_sap)
        end
      end

      def run
        wb = create_workbook
        workbook_to_tempfile wb, 'LlProdRiskReport-'
      end

      def send_email(settings)
        wb = create_workbook
        
        workbook_to_tempfile wb, 'LlProdRiskReport-' do |t|
          subject = "Products Needing Risk Assignment"
          body = "<p>Report attached.<br>--This is an automated message, please do not reply.<br>This message was generated from VFI Track</p>".html_safe
          OpenMailer.send_simple_html(settings['email'], subject, body, t).deliver!
        end
      end

      def query
        <<-SQL
          SELECT (CASE 
                  WHEN cv_ven.string_value IS NULL OR cv_ven.string_value = '' THEN CONCAT("None","/",c.id)
                  ELSE CONCAT(cv_ven.string_value,"/",c.id)
                  END) AS "Vendor SAP #", 
            c.name AS "Vendor Name", 
            p.unique_identifier AS "Product SAP #", 
            p.name AS "Product Name"
          FROM companies as c
            INNER JOIN product_vendor_assignments AS pva ON c.id = pva.vendor_id
            INNER JOIN products AS p on p.id = pva.product_id
            LEFT OUTER JOIN custom_values AS cv_ven ON (cv_ven.customizable_type = "company" AND cv_ven.customizable_id = c.id)
            LEFT OUTER JOIN custom_definitions AS cd_ven ON (cd_ven.module_type = "Company" AND cd_ven.label = 'SAP Company #')
            LEFT OUTER JOIN custom_values AS cv_prodven ON (cv_prodven.customizable_type = "ProductVendorAssignment" AND cv_prodven.customizable_id = pva.id) 
            LEFT OUTER JOIN custom_definitions AS cd_prodven ON (cd_prodven.module_type = "ProductVendorAssignment" AND cd_prodven.label = 'Risk')
          WHERE cv_prodven.string_value IS NULL OR cv_prodven.string_value = ''
          ORDER BY c.name
        SQL
      end
    end
  end
end