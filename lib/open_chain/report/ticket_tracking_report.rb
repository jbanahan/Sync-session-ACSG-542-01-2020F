require 'open_chain/report/builder_output_report_helper'

module OpenChain; module Report; class TicketTrackingReport
  include OpenChain::Report::BuilderOutputReportHelper

  VANDEGRIFT_PROJECT_KEYS ||= ["DEMO", "IT", "TP"]


  def self.permission? user
    (MasterSetup.get.system_code == 'www-vfitrack-net' || Rails.env.development?) && 
      (user.view_entries? && !get_project_keys(user).empty?)
  end

  def self.get_project_keys user
    if user.company.master?
      codes = VANDEGRIFT_PROJECT_KEYS + Company.where("ticketing_system_code <> '' AND ticketing_system_code IS NOT NULL")
                                               .pluck(:ticketing_system_code)
    else
      codes = [user.company.ticketing_system_code]
      user.company.linked_companies.each { |lc| codes << lc.ticketing_system_code }
    end
    codes.compact.sort_by(&:upcase)
  end

  def self.run_report run_by, settings
    self.new.run run_by, settings
  end
  
  def run run_by, settings
    start_date = sanitize_date_string settings['start_date'], run_by.time_zone
    end_date = sanitize_date_string settings['end_date'], run_by.time_zone
    project_keys = settings['project_keys']
    validate_ticketing_sys_codes(run_by, project_keys)
    wb = create_workbook start_date, end_date, project_keys, run_by.time_zone
    write_builder_to_tempfile wb, "TicketTrackingReport"
  end

  def validate_ticketing_sys_codes user, codes
    user_codes = self.class.get_project_keys user
    bad_codes = []
    codes.each { |c| bad_codes << c unless user_codes.include? c }
    raise "User isn't authorized to view project key(s) #{bad_codes.join(', ')}" unless bad_codes.empty?
  end

  def column_names
    ['Issue Number', 'Issue Type', 'Status', 'Summary', 'Order Number(s)',
     'Part Number(s)', 'Description', 'Comments', 'Assignee', 'Reporter',
     'Shipment ETA', 'Issue Created', 'Issue Resolved', 'Broker Reference',
     'Entry Number', 'PO Numbers', 'Part Numbers', 'Product Lines',
     'Vendors', 'MIDs', 'Countries of Origin', 'Master Bills', 'House Bills',
     'Container Numbers', 'Release Date', 'Link to Jira issue',
     'Link to VFI Track entry']
  end

  def create_workbook start_date, end_date, project_keys, time_zone
    wb = XlsxBuilder.new
    sheet = wb.create_sheet "Ticket Tracking Report"
    r = run_queries project_keys, start_date, end_date
    write_result_set_to_builder wb, sheet, r, data_conversions: conversions(time_zone, wb)
    wb
  end

  def run_queries project_keys, start_date, end_date
    execute_query(jira_query(project_keys, start_date, end_date)) do |jira_result|
      broker_refs = extract_broker_refs(jira_result).presence
      if broker_refs
        execute_query(vfi_query broker_refs) do |vfi_result|
          graft_results jira_result, vfi_result
        end
      else
        graft_results jira_result, []
      end
    end
  end

  def graft_results jira_result, vfi_result
    r = []
    vfi_hash = hash_results_by_broker_ref(vfi_result)
    jira_result.each do |jr| 
      #move the ticketing_system_code from the jira result to the vfi result
      jira_broker_ref = jr[13]
      if vfi_hash[jira_broker_ref]
        vfi_hash[jira_broker_ref][11] = jr.delete_at(14)
        r << (jr + vfi_hash[jira_broker_ref])
      else
        # There's no VFI Data to add, but we need add the jira link still
        jira_link = jr.delete_at(14)
        r << jr + [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, jira_link]
      end
    end
    r.sort_by{|res| res[11]}
  end

  def hash_results_by_broker_ref vfi_result
    h = {}
    vfi_result.each { |row| h[row[0]] = row.drop(1) }
    h
  end

  def extract_broker_refs jira_result
    jira_result.map { |jr| jr[13] }.compact.uniq
  end

  def comments_lambda
    lambda do |result_set_row, raw_column_value|
      q = ActiveRecord::Base.sanitize_sql_array(["SELECT actionbody FROM jiradb.jiraaction WHERE issueid = ? AND actiontype = 'comment' ORDER BY created", raw_column_value.to_i ])
      comments = ""
      execute_query(q) do |results|
        comments = results.map {|r| r[0] }.join "\n-----------------------\n"
      end
      # Trim results to 10,000 chars.  Some ticket comments values exceed the maximum
      # number of chars allowed by Excel (32,767 chars), causing Excel to error.
      # 10K is not 32K, but is still very generous for a report field.  32K was deemed
      # excessive.  Bigger field value and can lead to performance problems.
      comments[0...10000]
    end
  end

  def jira_url_lambda wb
    lambda do |result_set_row, raw_column_value|
      issue_num = result_set_row[0]
      ticketing_system_code = raw_column_value
      url = "http://ct.vfitrack.net/browse/#{ticketing_system_code}-#{issue_num}"
      wb.create_link_cell url
    end
  end

  def list_format_lambda
    lambda { |result_set_row, raw_column_value| raw_column_value.to_s.squish.split(/\s/).join(", ") }
  end

  def conversions(time_zone, wb)
    {"Issue Created" => datetime_translation_lambda(time_zone), 
     "Issue Resolved" => datetime_translation_lambda(time_zone), 
     "Release Date" => datetime_translation_lambda(time_zone),
     "Comments" => comments_lambda,
     "Order Number(s)" =>list_format_lambda,
     "Part Number(s)" =>list_format_lambda,
     "Link to VFI Track entry" => weblink_translation_lambda(wb, CoreModule::ENTRY.klass),
     "Link to Jira issue" => jira_url_lambda(wb)
     }
  end
  
  def jira_query project_keys, start_date, end_date
    q = <<-SQL
          SELECT i.issuenum AS 'Issue Number', 
                 t.pname AS 'Issue Type', 
                 s.pname AS 'Status', 
                 i.SUMMARY AS 'Summary', 
                 ordnum.STRINGVALUE AS 'Order Number(s)',
                 part.STRINGVALUE AS 'Part Number(s)',
                 LEFT(i.DESCRIPTION, 10000) AS 'Description', 
                 i.id AS 'Comments', 
                 i.ASSIGNEE 'Assignee', 
                 i.REPORTER 'Reporter', 
                 eta.DATEVALUE AS 'Shipment ETA', 
                 i.CREATED AS 'Issue Created', 
                 i.RESOLUTIONDATE AS 'Issue Resolved',
                 ship.STRINGVALUE AS 'Broker Reference',
                 p.pkey
          FROM jiradb.jiraissue i
            INNER JOIN jiradb.issuetype t ON t.ID = i.issuetype
            INNER JOIN jiradb.issuestatus s ON s.id = i.issuestatus
            INNER JOIN jiradb.project p ON p.id = i.PROJECT
            LEFT OUTER JOIN jiradb.jiraaction a on a.issueid = i.id AND a.actiontype = 'comment'
            LEFT OUTER JOIN jiradb.customfieldvalue ship ON ship.customfield = 10003 AND ship.issue = i.id
            LEFT OUTER JOIN jiradb.customfieldvalue eta ON eta.customfield = 10004 AND eta.issue = i.id
            LEFT OUTER JOIN jiradb.customfieldvalue ordnum ON ordnum.customfield = 10200 AND ordnum.issue = i.id
            LEFT OUTER JOIN jiradb.customfieldvalue part ON part.customfield = 10002 AND part.issue = i.id
          WHERE p.pkey IN (?)
            AND i.CREATED >= ? AND i.created < ?
          GROUP BY i.id
          ORDER BY ship.STRINGVALUE
        SQL
    ActiveRecord::Base.sanitize_sql_array([q, project_keys, start_date, end_date])
  end

  def vfi_query brok_ref_list
    q = <<-SQL
          SELECT e.broker_reference,
                 e.entry_number AS "Entry Number", 
                 e.po_numbers AS "PO Numbers", 
                 e.part_numbers AS "Part Numbers", 
                 e.product_lines AS "Product Lines", 
                 e.vendor_names AS "Vendors", 
                 e.mfids AS "MIDs", 
                 e.origin_country_codes AS "Countries of Origin", 
                 e.master_bills_of_lading AS "Master Bills", 
                 e.house_bills_of_lading AS "House Bills", 
                 e.container_numbers AS "Container Numbers", 
                 e.release_date AS "Release Date",
                 "URL" AS 'Link to Jira issue',
                 e.id AS "Link to VFI Track entry"
          FROM entries e
            INNER JOIN countries c ON c.id = e.import_country_id AND c.iso_code = "US"
          WHERE e.broker_reference IN (?)
          ORDER BY e.broker_reference
        SQL
    ActiveRecord::Base.sanitize_sql_array([q, brok_ref_list])
  end

end; end; end;
