require 'open_chain/report/report_helper'
module OpenChain
  module Report
    class MonthlyUserAuditReport
      include OpenChain::Report::ReportHelper

      def self.run_schedulable opts_hash={}
        recipients = User.where(admin: true, system_user: [false, nil], disabled: [false, nil]).pluck(:email)
        self.new.send_email('email' => recipients)
      end

      def create_workbook
        wb = XlsMaker.create_workbook "Monthly User Audit"
        table_from_query wb.worksheet(0), query, {'Username' => link_lambda}
        wb
      end

      def send_email(settings)
        wb = create_workbook
        
        workbook_to_tempfile wb, 'MonthlyUserAudit-' do |t|
          subject = "#{Time.now.strftime('%B')} VFI Track User Audit Report for #{MasterSetup.get.system_code}"
          body = "<p>Report attached.<br>--This is an automated message, please do not reply. <br> This message was generated from VFI Track</p>".html_safe
          OpenMailer.send_simple_html(settings['email'], subject, body, t).deliver!
        end
      end

      def link_lambda
        lambda { |result_set_row, raw_column_value|
          url = User.find(result_set_row[3]).url
          XlsMaker.create_link_cell url, raw_column_value
        }
      end

      def query
        <<-SQL
          SELECT users.company_id AS 'Company DB ID', 
            companies.name AS 'Company Name', 
            companies.system_code AS 'Company Code', 
            users.id AS 'User DB ID',
            users.last_request_at AS 'Last Activity',
            users.first_name AS 'First Name', 
            users.last_name AS 'Last Name', 
            users.username AS 'Username', 
            users.email AS 'Email', 
            users.department AS 'Department',
            IFNULL(portal_mode,'') AS 'Portal Mode', 
            IF(admin=1,'Yes','No') AS 'Admin',
            IF(sys_admin=1,'Yes','No') AS 'Sys Admin',
            IFNULL(group_concat(DISTINCT g.name),'') AS 'Groups',
            IF(disabled=1,'Yes','No') AS 'disabled',
            IF(broker_invoice_edit=1,'Yes','No') AS 'broker_invoice_edit',
            IF(broker_invoice_view=1,'Yes','No') AS 'broker_invoice_view',
            IF(classification_edit=1,'Yes','No') AS 'classification_edit',
            IF(commercial_invoice_edit=1,'Yes','No') AS 'commercial_invoice_edit',
            IF(commercial_invoice_view=1,'Yes','No') AS 'commercial_invoice_view',
            IF(delivery_attach=1,'Yes','No') AS 'delivery_attach',
            IF(delivery_comment=1,'Yes','No') AS 'delivery_comment',
            IF(delivery_delete=1,'Yes','No') AS 'delivery_delete',
            IF(delivery_edit=1,'Yes','No') AS 'delivery_edit',
            IF(delivery_view=1,'Yes','No') AS 'delivery_view',
            IF(drawback_edit=1,'Yes','No') AS 'drawback_edit',
            IF(drawback_view=1,'Yes','No') AS 'drawback_view',
            IF(entry_attach=1,'Yes','No') AS 'entry_attach',
            IF(entry_comment=1,'Yes','No') AS 'entry_comment',
            IF(entry_edit=1,'Yes','No') AS 'entry_edit',
            IF(entry_view=1,'Yes','No') AS 'entry_view',
            IF(order_attach=1,'Yes','No') AS 'order_attach',
            IF(order_comment=1,'Yes','No') AS 'order_comment',
            IF(order_delete=1,'Yes','No') AS 'order_delete',
            IF(order_edit=1,'Yes','No') AS 'order_edit',
            IF(order_view=1,'Yes','No') AS 'order_view',
            IF(product_attach=1,'Yes','No') AS 'product_attach',
            IF(product_comment=1,'Yes','No') AS 'product_comment',
            IF(product_delete=1,'Yes','No') AS 'product_delete',
            IF(product_edit=1,'Yes','No') AS 'product_edit',
            IF(product_view=1,'Yes','No') AS 'product_view',
            IF(project_edit=1,'Yes','No') AS 'project_edit',
            IF(project_view=1,'Yes','No') AS 'project_view',
            IF(sales_order_attach=1,'Yes','No') AS 'sales_order_attach',
            IF(sales_order_comment=1,'Yes','No') AS 'sales_order_comment',
            IF(sales_order_delete=1,'Yes','No') AS 'sales_order_delete',
            IF(sales_order_edit=1,'Yes','No') AS 'sales_order_edit',
            IF(sales_order_view=1,'Yes','No') AS 'sales_order_view',
            IF(security_filing_attach=1,'Yes','No') AS 'security_filing_attach',
            IF(security_filing_comment=1,'Yes','No') AS 'security_filing_comment',
            IF(security_filing_edit=1,'Yes','No') AS 'security_filing_edit',
            IF(security_filing_view=1,'Yes','No') AS 'security_filing_view',
            IF(shipment_attach=1,'Yes','No') AS 'shipment_attach',
            IF(shipment_comment=1,'Yes','No') AS 'shipment_comment',
            IF(shipment_delete=1,'Yes','No') AS 'shipment_delete',
            IF(shipment_edit=1,'Yes','No') AS 'shipment_edit',
            IF(shipment_view=1,'Yes','No') AS 'shipment_view',
            IF(simple_entry_mode=1,'Yes','No') AS 'simple_entry_mode',
            IF(support_agent=1,'Yes','No') AS 'support_agent',
            IF(survey_edit=1,'Yes','No') AS 'survey_edit',
            IF(survey_view=1,'Yes','No') AS 'survey_view',
            IF(variant_edit=1,'Yes','No') AS 'variant_edit',
            IF(vendor_attach=1,'Yes','No') AS 'vendor_attach',
            IF(vendor_comment=1,'Yes','No') AS 'vendor_comment',
            IF(vendor_edit=1,'Yes','No') AS 'vendor_edit',
            IF(vendor_view=1,'Yes','No') AS 'vendor_view'
          FROM users
            INNER JOIN companies ON companies.id = users.company_id
            LEFT OUTER JOIN user_group_memberships ugm ON ugm.user_id = users.id
            LEFT OUTER JOIN groups g ON g.id = ugm.group_id
          GROUP BY users.id
          ORDER BY users.disabled, companies.name 
        SQL
      end

    end
  end
end