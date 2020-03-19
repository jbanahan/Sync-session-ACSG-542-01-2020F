require 'open_chain/report/builder_output_report_helper'

module OpenChain; module Report; class IntacctExceptionReport
  include OpenChain::Report::BuilderOutputReportHelper

  def self.run_schedulable opts = {}
    emails = opts['email_to']
    companies = opts['companies']

    # Using count to ensure the values are Enumerables and not strings (string count method will error with ArgumentError)
    raise "At least one email address must be set." unless emails && emails.count > 0
    raise "At least one Intacct company must be set." unless companies && companies.count > 0

    self.new.run companies, emails
  end

  def run companies, email_to
    receivable_query = <<-SQL
SELECT id as 'Clear Error', company as 'Intacct Company', customer_number as 'Customer', invoice_number as 'Invoice Number', invoice_date as 'Invoice Date', intacct_errors as 'Suggested Fix', intacct_errors as 'Actual Intacct Error'
FROM intacct_receivables
WHERE intacct_errors IS NOT NULL and intacct_key IS NULL AND company IN (?)
SQL
    receivable_query = ActiveRecord::Base.sanitize_sql_array([receivable_query, companies])

    payable_query = <<-SQL
SELECT p.id as 'Clear Error', company as 'Intacct Company', (SELECT customer_number FROM intacct_payable_lines l WHERE l.intacct_payable_id = p.id LIMIT 1)  as 'Customer', vendor_number as 'Vendor', bill_number as 'Bill Number', bill_date as 'Bill Date', intacct_errors as 'Suggested Fix', intacct_errors as 'Actual Intacct Error'
FROM intacct_payables p
WHERE intacct_errors IS NOT NULL and intacct_key IS NULL AND company IN (?)
SQL
    payable_query = ActiveRecord::Base.sanitize_sql_array([payable_query, companies])
    check_query = <<-SQL
SELECT c.id as 'Clear Error', company as 'Intacct Company', customer_number  as 'Customer', vendor_number as 'Vendor', check_number as 'Check Number', check_date as 'Check Date', bill_number as 'Bill Number', intacct_errors as 'Suggested Fix', intacct_errors as 'Actual Intacct Error'
FROM intacct_checks c
WHERE intacct_errors IS NOT NULL and intacct_key IS NULL AND company IN (?)
SQL
    check_query = ActiveRecord::Base.sanitize_sql_array([check_query, companies])
    
    total_rows = 0
    wb = builder
    execute_query(receivable_query) do |result_set|
      if result_set.size > 0
        total_rows += result_set.size
        sheet = wb.create_sheet "Receivable Errors"
        write_result_set_to_builder(wb, sheet, result_set, data_conversions: {0=>link_lambda('receivable'), 5=>receivable_suggested_fix_lambda})
      end
    end

    execute_query(payable_query) do |result_set|
      if result_set.size > 0
        total_rows += result_set.size
        sheet = wb.create_sheet "Payable Errors"
        write_result_set_to_builder(wb, sheet, result_set, data_conversions: {0=>link_lambda('payable'), 6=>payable_suggested_fix_lambda})
      end
    end

    execute_query(check_query) do |result_set|
      if result_set.size > 0
        total_rows += result_set.size
        sheet = wb.create_sheet "Check Errors"
        write_result_set_to_builder(wb, sheet, result_set, data_conversions: {0=>link_lambda('check'), 7=>payable_suggested_fix_lambda})
      end
    end

    if total_rows > 0
      write_builder_to_tempfile(wb, "Intacct Integration Errors #{Time.zone.now.strftime("%m-%d-%Y")}") do |temp|
        OpenMailer.send_simple_html(email_to, "Intacct Integration Errors #{Time.zone.now.strftime("%m/%d/%Y")}", "The attached report lists all the outstanding Intacct integration errors for today.  Please resolve all these errors at your earliest convenience.<br><br>Contact support@vandegriftinc.com if you are unable to resolve any of the errors listed in the report.".html_safe, [temp]).deliver_now
      end
    end

    total_rows
  end

  private
    def link_lambda intacct_type
      lambda { |result_set_row, raw_column_value|
        url = XlsMaker.excel_url "/intacct_errors/#{raw_column_value}/clear_#{intacct_type}"
        XlsxBuilder.new.create_link_cell url, link_text: "Clear This Error"
      }
    end

    def receivable_suggested_fix_lambda 
      lambda { |result_set_row, raw_column_value|
        IntacctReceivable.suggested_fix raw_column_value
      }
    end

    def payable_suggested_fix_lambda 
      lambda { |result_set_row, raw_column_value|
        IntacctPayable.suggested_fix raw_column_value
      }
    end

    def builder
      XlsxBuilder.new
    end

end; end; end