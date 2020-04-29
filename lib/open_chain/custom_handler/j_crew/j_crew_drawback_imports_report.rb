require 'open_chain/report/report_helper'

module OpenChain; module CustomHandler; module JCrew; class JCrewDrawbackImportsReport
  include OpenChain::Report::ReportHelper

  def self.permission? user
    crew = Company.with_customs_management_number("JCREW").first
    user.view_entries? && crew.try(:can_view?, user) == true
  end

  def self.run_report run_by, opts = {}
    self.new.run run_by, opts
  end

  def run user, opts
    start_date, end_date = dates(user, opts)
    f = nil
    execute_query(query(start_date, end_date)) do |results|
      workbook, sheet = XlsMaker.create_workbook_and_sheet "Drawback Imports #{start_date.to_date.strftime("%m.%d.%Y")} - #{end_date.to_date.strftime("%m.%d.%Y")}", results.fields
      x = 0
      column_widths = []
      results.each do |result|
        # Have to write a distinct row to the excel file for each mbol found
        mbols = result[2].to_s.split(/\n */)
        mbols << "" if mbols.blank?
        mbols.each do |bol|
          row = result.clone
          row[2] = bol
          row[4] = row[4].in_time_zone(user.time_zone).to_date if row[4]
          XlsMaker.add_body_row sheet, (x+=1), row, column_widths, true
        end
      end

      f = workbook_to_tempfile workbook, "Drawback Imports ", file_name: "Drawback Imports Drawback Imports #{start_date.strftime("%Y-%m-%d")} - #{end_date.strftime("%Y-%m-%d")}.xls"
    end
    f
  end

  def dates user, opts
    opts = opts.with_indifferent_access
    [ActiveSupport::TimeZone[user.time_zone].parse(opts[:start_date]), ActiveSupport::TimeZone[user.time_zone].parse(opts[:end_date])]
  end


  def query start_date, end_date
    <<-QRY
      SELECT e.broker_reference 'Broker Reference', e.entry_number 'Entry Number', e.master_bills_of_lading 'Master Bill', e.customer_number 'Customer Number', e.arrival_date 'Arrival Date', l.po_number 'Invoice Line - PO Number',
      l.part_number 'Invoice Line - Part Number', l.country_origin_code 'Invoice Line - Country Origin Code', l.quantity 'Invoice Line - Units'
      FROM entries e
      INNER JOIN commercial_invoices i ON i.entry_id = e.id
      INNER JOIN commercial_invoice_lines l ON l.commercial_invoice_id = i.id
      WHERE e.customer_number IN ('JCREW', 'J0000') AND e.release_date IS NOT NULL
      AND l.po_number <> '' AND l.part_number <> ''
      AND e.arrival_date >= '#{start_date.in_time_zone("UTC")}' and e.arrival_date < '#{end_date.in_time_zone("UTC")}'
      order by e.arrival_date, l.line_number
    QRY
  end

end; end; end; end;