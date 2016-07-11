require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'
require 'open_chain/report/report_helper'
module OpenChain
  module Report
    class LlProdRiskReport
      include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
      include OpenChain::Report::ReportHelper
      include Rails.application.routes.url_helpers

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
        table_from_query wb.worksheet(0), query(custom_defs[:prodven_risk], custom_defs[:cmp_sap_company]), {'Vendor SAP #' => link_lambda}, query_column_offset: 1
        wb
      end

      def link_lambda
        lambda do |result_set_row, raw_column_value|
          vendor_sap = raw_column_value.presence || "None"
          vendor_sap_link = XlsMaker.excel_url(vendor_path(result_set_row[0]))
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
select 
v.id as 'ID',
sap.string_value as 'Vendor SAP #',
v.name as 'Company Name',
p.unique_identifier as 'Product SAP #',
p.name as 'Product Name',
group_concat(distinct orders.order_number) as 'Order Numbers',
min(orders.ship_window_start) as 'Ship Window Start'
from orders
inner join order_lines on orders.id = order_lines.order_id
inner join products p on p.id = order_lines.product_id
inner join companies v on v.id = orders.vendor_id
left join product_vendor_assignments pva on pva.vendor_id = v.id and pva.product_id = p.id
left outer join custom_values risk on risk.custom_definition_id = #{cd_prodven_risk.id} and risk.customizable_type = 'ProductVendorAssignment' and risk.customizable_id = pva.id
left outer join custom_values sap on sap.custom_definition_id = #{cd_cmp_sap_company.id} and sap.customizable_type = 'Company' and sap.customizable_id = v.id
WHERE orders.closed_at is not null and length(trim(ifnull(risk.string_value, ''))) = 0 and orders.ship_window_start >= '2016-01-01'
group by p.id, v.id
order by v.name, p.name
        SQL
      end
    end
  end
end
