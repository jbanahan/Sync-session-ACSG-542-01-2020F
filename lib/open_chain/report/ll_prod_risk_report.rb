require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'
require 'open_chain/report/report_helper'
module OpenChain
  module Report
    class LlProdRiskReport
      include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
      include OpenChain::Report::ReportHelper

      LINK_STEM ||= "#{Rails.env.production? ? "https" : "http"}://#{MasterSetup.get.request_host}/vendors/"
      
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
        headers = ["Vendor SAP #", "Vendor Name", "Product SAP #", "Product Name", "Order Count"]
        wb, sheet = XlsMaker.create_workbook_and_sheet "Products Needing Risk Assignment"
        
        custom_defs = self.class.prep_custom_definitions([:prodven_risk,:cmp_sap_company])
        sc = SearchCriterion.new(model_field_uid:custom_defs[:prodven_risk].model_field_uid, operator:"null")
        rows = compile_rows(sc, custom_defs)
        table_from_query_result sheet, rows, {}, {column_names: headers}
        wb
      end

      def compile_rows(search_criterion, custom_definitions)
        rows = []; count = 0
        search_criterion.apply(ProductVendorAssignment).limit(25000).each do |pva|
          vendor_sap = custom_definitions[:cmp_sap_company].model_field.process_export(pva.vendor,nil,true)
          count += 1
          row = []
          row << (vendor_sap ? XlsMaker.create_link_cell(LINK_STEM + pva.vendor_id.to_s, vendor_sap) : "")
          row << ModelField.find_by_uid(:cmp_name).process_export(pva.vendor,nil,true)
          row << ModelField.find_by_uid(:prod_uid).process_export(pva.product,nil,true)
          row << ModelField.find_by_uid(:prod_name).process_export(pva.product,nil,true)
          row << ModelField.find_by_uid(:prodven_prod_ord_count).process_export(pva,nil,true)
          rows << row
          rows << ['This report is limited to 25,000 lines.','','','',''] if count >= 25000
        end
        rows.sort!{|a, b| a[1] <=> b[1]}
      end

      def run
        wb = create_workbook
        workbook_to_tempfile wb, 'LlProdRiskReport-'
      end

      def send_email(settings)
        wb = create_workbook
        
        workbook_to_tempfile wb, 'LlProdRiskReport-' do |t|
          subject = "Products Needing Risk Assignment"
          body = "<p>Report attached.<br>--This is an automated message, please do not reply. <br> This message was generated from VFI Track</p>".html_safe
          OpenMailer.send_simple_html(settings['email'], subject, body, t).deliver!
        end
      end
    end
  end
end