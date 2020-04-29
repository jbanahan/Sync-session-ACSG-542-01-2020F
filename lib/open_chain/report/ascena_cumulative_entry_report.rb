require 'open_chain/report/report_helper'
require 'open_chain/fiscal_calendar_scheduling_support'

module OpenChain; module Report; class AscenaCumulativeEntryReport
  include OpenChain::Report::ReportHelper
  extend OpenChain::FiscalCalendarSchedulingSupport

  CUSTOMER_NUMBER = "ASCE"

  def self.run_schedulable settings={}
    settings['company'] = 'ASCENA'
    run_if_configured(settings) do |fiscal_month, fiscal_date|
      self.new.run(settings['email'], fiscal_month.back(1))
    end
  end

  def run email, fiscal_month
    wb = create_workbook(fiscal_month)
    send_email(email, wb, fiscal_month.fiscal_descriptor)
  end

  def create_workbook fiscal_month
    fm_num, fy = fiscal_month.month_number, fiscal_month.year
    start_date = fiscal_month.start_date.strftime("%Y-%m-%d")
    end_date = fiscal_month.end_date.strftime("%Y-%m-%d")

    wb = XlsMaker.new_workbook
    add_main_sheet wb, fm_num, fy
    add_isf_sheet wb, start_date, end_date
    wb
  end

  def add_main_sheet wb, fiscal_month, fiscal_year
    XlsMaker.create_sheet wb, "Main"
    table_from_query wb.worksheets.last, main_query(fiscal_month, fiscal_year)
  end

  def add_isf_sheet wb, start_date, end_date
    XlsMaker.create_sheet wb, "ISF"
    table_from_query wb.worksheets.last, isf_query(start_date, end_date)
  end

  def send_email addresses, workbook, fiscal_descriptor
    title = "Ascena Cumulative Entry Report for #{fiscal_descriptor}"
    body = "Attached is the #{title}."
    workbook_to_tempfile(workbook, "report", file_name: "#{title}.xls") do |t|
      workbook.write t
      t.flush
      OpenMailer.send_simple_html(addresses, title, "Attached is the #{title}", t).deliver_now
    end
  end

  def us
    @country ||= Country.where(iso_code: "US").first
    raise "United States not found." unless @country
    @country
  end

  def main_query fiscal_month, fiscal_year
    <<-SQL
      SELECT COUNT(entry_number) AS 'Total Entries',
             SUM(IF(transport_mode_code IN (40, 41),1,0)) AS 'Air Entries',
             SUM(IF(transport_mode_code IN (10, 11),1,0)) AS 'Ocean Entries',
             SUM((SELECT COUNT(*)
                  FROM commercial_invoices
                    INNER JOIN commercial_invoice_lines ON commercial_invoices.id = commercial_invoice_lines.commercial_invoice_id
                  WHERE commercial_invoices.entry_id = entries.id)) AS 'Invoice Line Count',
             SUM((SELECT COUNT(*)
                  FROM commercial_invoices
                  WHERE commercial_invoices.entry_id = entries.id)) AS 'Invoice Count',
             SUM(IF(transport_mode_code IN (40,41),gross_weight,0)) AS 'Air Weight',
             SUM(IF(transport_mode_code IN (10,11),gross_weight,0)) AS 'Ocean Weight',
             SUM(entries.mpf) AS 'MPF',
             SUM(entries.entered_value) AS 'Entered Value',
             SUM(entries.total_duty) AS 'Total Duty'
      FROM entries
      WHERE import_country_id = #{us.id} AND customer_number = '#{CUSTOMER_NUMBER}'
            AND fiscal_month = #{fiscal_month} AND fiscal_year = #{fiscal_year}
    SQL
  end

  def isf_query start, finish
    <<-SQL
      SELECT COUNT(*) AS "Count"
      FROM security_filings
      WHERE security_filings.importer_account_code = '#{CUSTOMER_NUMBER}' AND first_sent_date between '#{start}' AND '#{finish}'
    SQL
  end


end; end; end;
