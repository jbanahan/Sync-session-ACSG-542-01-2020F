require 'open_chain/report/report_helper'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module Report; class MissingStatementSummaryEntryReport
  include OpenChain::Report::ReportHelper

  def self.get_start_date
    initial_start_date = Time.zone.parse("1/1/2018")
    window_start = Time.zone.now.beginning_of_day - 6.months
    window_start > initial_start_date ? window_start : initial_start_date
  end

  def self.run_schedulable opts = {}
    emails = opts['email_to'].split("\n")
    start_day = opts['start_date'].present? ? Time.zone.parse(opts['start_date']) : get_start_date
    end_day = opts['end_date'].present? ? Time.zone.parse(opts['end_date']) : Time.zone.now
    start_date = (start_day).beginning_of_day.in_time_zone("America/New_York")
    end_date = (end_day).end_of_day.in_time_zone("America/New_York")

    self.new.run emails, start_date, end_date
  end

  def run emails, start_date=nil, end_date=nil
    qry = query(start_date, end_date)

    wb = XlsMaker.create_workbook 'Statement Entry Summary Not On File'
    sheet = wb.worksheets[0]
    rows = table_from_query sheet, qry
    if rows == 0
      XlsMaker.add_body_row sheet, 1, ["No entries missing summaries"]
    end

    workbook_to_tempfile(wb, "Statement Entry Summary not on File", file_name: "Statement Entry Summary Not On File - #{Time.zone.now.to_date}.xls") do |t|
      OpenMailer.send_simple_html(emails,
                                  "[VFI Track] Statement Entry Summary not on File- #{start_date.to_date}", "The attached report lists all entries with a missing entry summary from #{start_date.to_date}".html_safe,
                                  [t]
      ).deliver!
    end
  end

  def query(start_date, end_date)
"SELECT DISTINCT
    e.broker_reference AS 'Broker Reference',
    DATE(e.entry_filed_date) AS 'Entry Filed Date',
    DATE(e.release_date) AS 'Release Date',
    e.release_cert_message AS 'Release Certification Message',
    e.entry_port_code AS 'Port Code',
    p.name AS 'Port Name',
    n.body AS 'User Notes'
FROM
    entries e
        INNER JOIN
    entry_comments n ON e.id = n.entry_id
        INNER JOIN
    ports p ON e.entry_port_code = p.schedule_d_code
WHERE
        e.last_exported_from_source > '#{start_date}' AND e.last_exported_from_source < '#{end_date}'
        AND n.body LIKE '%STMNT ENTRY SUMMARY NOT ON FILE%'
        AND e.source_system = 'Alliance'"
  end
end; end; end
