module OpenChain; module Report; class TicketTrackingReport
  include OpenChain::Report::ReportHelper

  COLUMN_NAMES ||= ['Issue Number', 'Issue Type', 'Status', 'Summary', 'Description', 'Comments', 'Assignee', 'Reporter', 'Shipment ETA', 
                    'Issue Created', 'Issue Resolved', 'Broker Reference', 'Entry Number', 'PO Numbers', 'Part Numbers', 'Product Lines', 
                    'Vendors', 'MIDs', 'Countries of Origin', 'Master Bills', 'House Bills', 'Container Numbers', 'Release Date', 
                    'Link to Jira issue', 'Link to VFI Track entry']

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
    workbook_to_tempfile wb, 'TicketTracking-', file_name: "Ticket Tracking Report.xls"
  end

  def validate_ticketing_sys_codes user, codes
    user_codes = self.class.get_project_keys user
    bad_codes = []
    codes.each { |c| bad_codes << c unless user_codes.include? c }
    raise "User isn't authorized to view project key(s) #{bad_codes.join(', ')}" unless bad_codes.empty?
  end

  def create_workbook start_date, end_date, project_keys, time_zone
    wb, sheet = XlsMaker.create_workbook_and_sheet "Ticket Tracking Report"
    r = run_queries project_keys, start_date, end_date
    table_from_query_result sheet, r, conversions(time_zone), {column_names: COLUMN_NAMES}
    wb
  end

  def run_queries project_keys, start_date, end_date
    jira_result = ActiveRecord::Base.connection.execute jira_query(project_keys, start_date, end_date)
    broker_refs = extract_broker_refs(jira_result).presence || ""
    vfi_result = ActiveRecord::Base.connection.execute vfi_query broker_refs
    graft_results jira_result, vfi_result
  end

  def graft_results jira_result, vfi_result
    r = []
    vfi_hash = hash_results_by_broker_ref(vfi_result)
    jira_result.each do |jr| 
      #move the ticketing_system_code from the jira result to the vfi result
      jira_broker_ref = jr[11]
      if vfi_hash[jira_broker_ref]
        vfi_hash[jira_broker_ref][11] = jr.delete_at(12)
        r << (jr + vfi_hash[jira_broker_ref])
      else
        # There's no VFI Data to add, but we need add the jira link still
        jira_link = jr.delete_at(12)
        r << jr + [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, jira_link]
      end
    end
    r.sort_by{|r| r[9]}
  end

  def hash_results_by_broker_ref vfi_result
    h = {}
    vfi_result.each { |row| h[row[0]] = row.drop(1) }
    h
  end

  def extract_broker_refs jira_result
    jira_result.map { |jr| jr[11] }.compact.uniq
  end
  
  def comments_lambda 
    lambda do |result_set_row, raw_column_value|
      results = ActiveRecord::Base.connection.execute "SELECT actionbody FROM jiradb.jiraaction WHERE issueid = #{raw_column_value.to_i} AND actiontype = 'comment' ORDER BY created"
      results.map {|r| r[0] }.join "\n-----------------------\n"
    end
  end

  def jira_url_lambda
    lambda { |result_set_row, raw_column_value|
      issue_num = result_set_row[0]
      ticketing_system_code = raw_column_value
      url = "http://ct.vfitrack.net/browse/#{ticketing_system_code}-#{issue_num}"
      XlsMaker.create_link_cell url
    }
  end

  def conversions(time_zone)
    {"Issue Created" => datetime_translation_lambda(time_zone), 
     "Issue Resolved" => datetime_translation_lambda(time_zone), 
     "Release Date" => datetime_translation_lambda(time_zone),
     "Comments" => comments_lambda,
     "Link to VFI Track entry" => weblink_translation_lambda(CoreModule::ENTRY),
     "Link to Jira issue" => jira_url_lambda}
  end
  
  def jira_query project_keys, start_date, end_date
    <<-SQL
      SELECT i.issuenum AS 'Issue Number', 
             t.pname AS 'Issue Type', 
             s.pname AS 'Status', 
             i.SUMMARY AS 'Summary', 
             i.DESCRIPTION AS 'Description', 
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
      WHERE p.pkey IN (#{project_keys.map{|c| ActiveRecord::Base.sanitize c}.join(', ')})
        AND i.CREATED >= '#{start_date}' AND i.created < '#{end_date}'
      GROUP BY i.id
      ORDER BY ship.STRINGVALUE
    SQL
  end

  def vfi_query brok_ref_list
    <<-SQL
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
      WHERE e.broker_reference IN (#{brok_ref_list.map{|x| "'#{x}'"}.join(",")})
      ORDER BY e.broker_reference
    SQL
  end

end; end; end;