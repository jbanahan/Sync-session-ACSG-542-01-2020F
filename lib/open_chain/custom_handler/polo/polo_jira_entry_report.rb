require 'open_chain/report/report_helper'

module OpenChain; module CustomHandler; module Polo; class PoloJiraEntryReport
  include OpenChain::Report::ReportHelper

  def self.permission? user
    (Rails.env.development? || MasterSetup.get.system_code == "www-vfitrack-net") && user.view_entries? &&
        (user.company.master? || user.company.system_code == 'RLMASTER')
  end

  def self.run_report user, settings = {}
    self.new.run(user, settings)
  end

  def self.run_schedulable settings={}
    raise "Scheduled instances of the Jira Ticket Discrepancy Report must include an email_to setting with an array of email addresses." unless settings['email_to'] && settings['email_to'].respond_to?(:each)
    current_datetime = ActiveSupport::TimeZone["America/New_York"].now()
    report_start = current_datetime.beginning_of_month - 1.month
    settings['start_date'] = report_start.strftime("%Y-%m-%d")
    settings['end_date'] = current_datetime.beginning_of_month.strftime("%Y-%m-%d")
    temp = nil
    begin
      temp = self.new.run User.integration, settings
      report_month_formatted = report_start.strftime("%m/%Y")
      subject = "[VFI Track] Jira Ticket Discrepancy Report for the Month of #{report_month_formatted}"
      body = "Attached please find the Jira Ticket Discrepancy Report for the Month of #{report_month_formatted}.  For any issues related to the report or to change the report email distribution list, please contact VFI Track Support at vfitrack_support@vandegriftinc.com."
      OpenMailer.send_simple_html(settings['email_to'], subject, body, [temp]).deliver_now
    ensure
      temp.close! if temp && temp.respond_to?(:close!) && !temp.closed?
    end
  end

  def run user, settings = {}
    start_date = Date.parse(settings['start_date'])
    end_date = Date.parse(settings['end_date'])

    filename = "RL Jira #{start_date.to_s} - #{end_date}"
    wb = XlsMaker.create_workbook filename
    dt_lambda = datetime_translation_lambda(user.time_zone, true)

    table_from_query wb.worksheet(0), query(start_date, end_date), {"Issue Create Date" => dt_lambda, "Resolved Date" => dt_lambda, "Comments" => comments_lambda}

    workbook_to_tempfile wb, 'RlJira-', file_name: "#{filename}.xls"
  end

  def comments_lambda
    lambda do |result_set_row, raw_column_value|
      qry = "SELECT actionbody FROM jiradb.jiraaction WHERE issueid = #{raw_column_value.to_i} AND actiontype = 'comment' ORDER BY created"
      execute_query(qry) do |results|
        results.map {|r| r[0] }.join "\n-----------------------\n"
      end
    end
  end

  def query start_date, end_date
    # Just baseline the logged date to 6 months prior to the start date (this is primarily there to speed up the cross system join)
    logged_date_start = start_date - 6.months
    query = <<-SQL
      select v.STRINGVALUE as 'Shipment ID', t.pname as 'Issue Type', concat('RL-', i.issuenum) as 'Issue Number', i.SUMMARY as 'Summary', i.DESCRIPTION as 'Description', i.id as 'Comments' , i.CREATED as 'Issue Create Date', i.RESOLUTIONDATE as 'Resolved Date', s.pname as 'Current Status',
      e.importer_tax_id as 'Importer Tax Id', e.vendor_names as 'Shipper Names', e.eta_date as 'ETA Date', e.po_numbers as 'PO #', e.part_numbers as 'Styles', e.commercial_invoice_numbers as 'Invoice #', '' as 'URL', substring(e.part_numbers, 1, 3) as 'Brand', e.entry_type as 'Entry Type'
      from jiradb.jiraissue i
      left outer join jiradb.issuetype t on t.ID = i.issuetype
      left outer join jiradb.issuestatus s on s.id = i.issuestatus
      left outer join jiradb.customfieldvalue v on v.customfield = 10003 and v.issue = i.id
      left outer join wwwvfitracknet.entries e on e.source_system = 'Fenix' and (e.entry_number = v.stringvalue OR e.broker_reference = v.stringvalue OR e.cargo_control_number = v.stringvalue OR e.master_bills_of_lading = v.stringvalue) and e.importer_tax_id in ('806167003RM0001', '871349163RM0001', '866806458RM0001', '806167003RM0002') and e.file_logged_date >= '#{logged_date_start}'
      where i.PROJECT = 10101
      and i.CREATED >= '#{start_date}' and i.created < '#{end_date}'
      order by i.CREATED asc
    SQL

  end

end; end; end; end;
