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

    XlsMaker.add_body_row sheet, 0, ['Broker Reference', 'Entry Filed Date', 'Release Date', 'Release Certification Message', 'Port Code', 'Port Name', 'User Notes']

    results = ActiveRecord::Base.connection.execute qry
    invalid_entries = []

    results.each do |result|
      entry = Entry.find(result[0])
      note = entry.entry_comments.find(result[1])
      fixed_note = entry.entry_comments.where("entry_comments.created_at >= ? AND (entry_comments.body LIKE '%SUMMARY HAS BEEN ADDED%' or entry_comments.body like '%SUMMARY HAS BEEN REPLACED%')", note.created_at)
      next if fixed_note.present?
      invalid_entries << {entry: entry, note: note}
    end

    if invalid_entries.blank?
      XlsMaker.add_body_row sheet, 1, ["No entries missing summaries"]
    else
      row = 1
      invalid_entries.each do |entry_hash|
        entry = entry_hash[:entry]
        note = entry_hash[:note]
        XlsMaker.add_body_row sheet, row, [entry.broker_reference, entry.entry_filed_date, entry.release_date, entry.release_cert_message, entry.entry_port_code, entry.entry_port.name, note.body]
        row += 1
      end
    end

    workbook_to_tempfile(wb, "Statement Entry Summary not on File", file_name: "Statement Entry Summary Not On File - #{Time.zone.now.to_date}.xls") do |t|
      OpenMailer.send_simple_html(emails,
                                  "[VFI Track] Statement Entry Summary not on File- #{start_date.to_date}", "The attached report lists all entries with a missing entry summary from #{start_date.to_date}".html_safe,
                                  [t]
      ).deliver_now
    end
  end

  def query(start_date, end_date)
"SELECT DISTINCT
    e.id, n.id
FROM
    entries e
        INNER JOIN
    entry_comments n ON e.id = n.entry_id
WHERE
        e.last_exported_from_source > '#{start_date}' AND e.last_exported_from_source < '#{end_date}'
        AND n.body LIKE '%STMNT ENTRY SUMMARY NOT ON FILE%'
        AND e.source_system = 'Alliance'
ORDER BY n.created_at DESC"
  end
end; end; end
