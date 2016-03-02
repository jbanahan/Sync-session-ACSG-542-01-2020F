require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'
require 'open_chain/report/report_helper'
module OpenChain
  module Report
    class LlProdRiskReport
      include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
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
        custom_defs = self.class.prep_custom_definitions([:prodven_risk,:cmp_sap_company])
        table_from_query wb.worksheet(0), query(custom_defs[:prodven_risk], custom_defs[:cmp_sap_company]), {'Vendor SAP #' => link_lambda} 
        wb
      end

      def link_lambda
        lambda do |result_set_row, raw_column_value| 
          vendor_sap, vendor_id = raw_column_value.split("~*~")
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

      def query(cd_prodven_risk, cd_cmp_sap_company)
        <<-SQL
          SELECT (CASE 
                  WHEN cv_ven.string_value IS NULL OR cv_ven.string_value = '' THEN CONCAT("None","~*~",c.id)
                  ELSE CONCAT(cv_ven.string_value,"~*~",c.id)
                  END) AS "Vendor SAP #", 
            c.name AS "Vendor Name", 
            p.unique_identifier AS "Product SAP #", 
            p.name AS "Product Name"
          FROM companies as c
            INNER JOIN product_vendor_assignments AS pva ON c.id = pva.vendor_id
            INNER JOIN products AS p on p.id = pva.product_id
            LEFT OUTER JOIN custom_values AS cv_ven ON (cv_ven.customizable_type = "company" AND cv_ven.customizable_id = c.id 
                                                        AND cv_ven.custom_definition_id = #{cd_cmp_sap_company.id})
            LEFT OUTER JOIN custom_values AS cv_prodven ON (cv_prodven.customizable_type = "ProductVendorAssignment" AND cv_prodven.customizable_id = pva.id
                                                        AND cv_prodven.custom_definition_id = #{cd_prodven_risk.id})
          WHERE cv_prodven.string_value IS NULL OR cv_prodven.string_value = ''
          ORDER BY c.name
        SQL
      end
    end
  end
end