require 'open_chain/report/report_helper'

module OpenChain; module Report; class IntacctExceptionReport
  include ReportHelper

  def self.run_schedulable opts = {}
    emails = opts['email_to']
    companies = opts['companies']

    # Using count to ensure the values are Enumerables and not strings (string count method will error with ArgumentError)
    raise "At least one email address must be set." unless emails && emails.count > 0
    raise "At least one Intacct company must be set." unless companies && companies.count > 0

    self.new.run companies, emails
  end

  def run companies, email_to
    # Even though companies will only ever be set by a dev and will never validly have an apostrophe, I can't
    # bring myself to not quote them
    company_clause = companies.collect {|c| ActiveRecord::Base.connection.quote(c)}.join(", ")

    receivable_query = <<-SQL
SELECT id as 'Clear Error', company as 'Intacct Company', customer_number as 'Customer', invoice_number as 'Invoice Number', invoice_date as 'Invoice Date', intacct_errors as 'Suggested Fix', intacct_errors as 'Actual Intacct Error'
FROM intacct_receivables
WHERE intacct_errors IS NOT NULL and intacct_key IS NULL AND company IN (#{company_clause})
SQL

    payable_query = <<-SQL
SELECT p.id as 'Clear Error', company as 'Intacct Company', (SELECT customer_number FROM intacct_payable_lines l WHERE l.intacct_payable_id = p.id LIMIT 1)  as 'Customer', vendor_number as 'Vendor', bill_number as 'Bill Number', bill_date as 'Bill Date', intacct_errors as 'Suggested Fix', intacct_errors as 'Actual Intacct Error'
FROM intacct_payables p
WHERE intacct_errors IS NOT NULL and intacct_key IS NULL AND company IN (#{company_clause})
SQL
    check_query = <<-SQL
SELECT c.id as 'Clear Error', company as 'Intacct Company', customer_number  as 'Customer', vendor_number as 'Vendor', check_number as 'Check Number', check_date as 'Check Date', bill_number as 'Bill Number', intacct_errors as 'Suggested Fix', intacct_errors as 'Actual Intacct Error'
FROM intacct_checks c
WHERE intacct_errors IS NOT NULL and intacct_key IS NULL AND company IN (#{company_clause})
SQL

    total_rows = 0
    wb = XlsMaker.create_workbook 'Receivable Errors'
    sheet = wb.worksheets[0]
    rows = table_from_query sheet, receivable_query, {0=>link_lambda('receivable'), 5=>receivable_suggested_fix_lambda}
    total_rows += rows
    if rows == 0
      XlsMaker.add_body_row sheet, 1, ["No Intacct Receivable errors to report."]
    end

    sheet = XlsMaker.create_sheet wb, "Payable Errors"
    rows = table_from_query sheet, payable_query, {0=>link_lambda('payable'), 6=>payable_suggested_fix_lambda}
    total_rows += rows
    if rows == 0
      XlsMaker.add_body_row sheet, 1, ["No Intacct Payable errors to report."]
    end

    sheet = XlsMaker.create_sheet wb, "Check Errors"
    rows = table_from_query sheet, check_query, {0=>link_lambda('check'), 7=>payable_suggested_fix_lambda}
    total_rows += rows
    if rows == 0
      XlsMaker.add_body_row sheet, 1, ["No Intacct Check errors to report."]
    end

    if total_rows > 0
      temp = nil
      begin
        temp = workbook_to_tempfile wb, "Intacct Integration Errors #{Time.zone.now.strftime("%m-%d-%Y")}"
        Attachment.add_original_filename_method temp
        temp.original_filename = "Intacct Integration Errors #{Time.zone.now.strftime("%m-%d-%Y")}.xls"
        OpenMailer.send_simple_html(email_to, "Intacct Integration Errors #{Time.zone.now.strftime("%m/%d/%Y")}", "The attached report lists all the outstanding Intacct integration errors for today.  Please resolve all these errors at your earliest convenience.<br><br>Contact support@vandegriftinc.com if you are unable to resolve any of the errors listed in the report.".html_safe, [temp]).deliver!
      ensure 
        temp.close! unless temp.nil? || temp.closed?
      end
    end
    total_rows
  end

  private
    def link_lambda intacct_type
      lambda { |result_set_row, raw_column_value|
        url = XlsMaker.excel_url "/intacct_errors/#{raw_column_value}/clear_#{intacct_type}"
        XlsMaker.create_link_cell url, "Clear This Error"
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

end; end; end