require 'open_chain/report/report_helper'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberPpqReport
  include OpenChain::Report::ReportHelper

  def self.run_schedulable opts = {}
    self.new.email_report *start_end_dates, opts['email_to']
  end

  def email_report start_date, end_date, email_to
    run_time = Time.zone.now.in_time_zone(user_timezone).to_date
    wb = run_report(start_date, end_date)
    subject = "PPQ Report #{run_time.strftime('%m/%d/%y')}"
    workbook_to_tempfile(wb, "Lumber_PPQ", file_name: "PPQ Report #{run_time.strftime('%m-%d-%y')}.xls") do |temp|
      OpenMailer.send_simple_html(email_to, subject, "Attached is the PPQ Report for #{run_time.strftime('%m/%d/%y')}.", temp).deliver_now
    end
  end

  def run_report start_date, end_date
    wb, sheet = XlsMaker.create_workbook_and_sheet "Lacey Data #{start_date.in_time_zone(user_timezone).strftime '%m.%d.%y'} - #{(end_date.in_time_zone(user_timezone) - 1.day).strftime '%m.%d.%y'}", nil
    table_from_query sheet, query(start_date, end_date), conversions
    wb
  end

  def query start_date, end_date
    <<-SQL
      SELECT '' as 'Unique Id', e.customer_name 'Importer Name', e.entry_number 'Entry Number', e.master_bills_of_lading 'B/L No(s)', e.container_numbers 'Container No(s)', e.arrival_date 'Arrival Date', i.mfid 'Manufacturer ID', l.part_number 'Part No', l.po_number 'PO No', t.hts_code 'HTS No',
      lc.detailed_description 'Description', lc.name 'Name of Constituent Element',lc.quantity 'Quantity of Constituent Element', lc.unit_of_measure 'UOM', lc.percent_recycled_material 'Percent Recycled', lc.value  'PGA Line Value', lc.genus  'Scientific Genus Name', lc.species  'Scientific Species Name',
      lc.harvested_from_country  'Source Country Code'
      FROM entries e
      INNER JOIN commercial_invoices i ON e.id = i.entry_id
      INNER JOIN commercial_invoice_lines l ON i.id = l.commercial_invoice_id
      INNER JOIN commercial_invoice_tariffs t ON l.id = t.commercial_invoice_line_id
      LEFT OUTER JOIN commercial_invoice_lacey_components lc ON lc.commercial_invoice_tariff_id = t.id
      WHERE e.customer_number = 'LUMBER' AND e.source_system = 'Alliance' AND e.release_date >= '#{start_date.to_s(:db)}' and e.release_date < '#{end_date.to_s(:db)}'
      ORDER BY e.arrival_date, e.broker_reference, i.id, l.line_number, t.id, lc.id
    SQL
  end

  def conversions
    c = {}

    # The first column needs to be a counter that literally just counts the lines on the report
    counter = 0
    c['Unique Id'] = lambda {|row, value| counter += 1 }
    c['HTS No'] = lambda {|row, value| value.to_s.hts_format }
    c['B/L No(s)']= csv_translation_lambda
    c['Container No(s)']= csv_translation_lambda
    c['Arrival Date'] = datetime_translation_lambda(user_timezone, true)
    c
  end

  def self.user_timezone
    "America/New_York"
  end

  def user_timezone
    self.class.user_timezone
  end

  def self.start_end_dates
    # Calculate start/end dates using the run date as the previous workweek (Monday - Sunday)
    now = Time.zone.now.in_time_zone(user_timezone)
    start_date = (now - 7.days)
    # Subtract days until we're at a Monday
    start_date -= 1.day while start_date.wday != 1
    # Basically, we're formatting these dates so the represent the Monday @ Midnight and the following Monday @ midnight, relying on the
    # where clause being >= && <.  We don't want any results showing that are actually on the following Monday based on Eastern timezone
    [start_date.beginning_of_day.in_time_zone("UTC"), (start_date + 7.days).beginning_of_day.in_time_zone("UTC")]
  end

end; end; end; end;