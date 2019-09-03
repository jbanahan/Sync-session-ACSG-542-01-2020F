require 'open_chain/report/report_helper'
require 'open_chain/mutable_number'

module OpenChain; class ActivitySummary

  DETAILS = {'1w' => 'Released In The Last 7 Days', 
             '4w' => 'Released In The Last 28 Days', 
             'op' => 'Filed / Not Released', 
             'ytd' => 'Released Year To Date', 
             'holds' => 'Entries On Hold'}

  def self.generate_us_entry_summary company_id, base_date=Time.zone.now.midnight
    {'activity_summary'=>generator_for_country("US").generate_hash(company_id, base_date)}
  end
  def self.generate_ca_entry_summary company_id, base_date=Time.zone.now.midnight
    {'activity_summary'=>generator_for_country("CA").generate_hash(company_id, base_date)}
  end

  def self.generator_for_country iso
    case iso.upcase
    when 'US'
      return USEntrySummaryGenerator.new
    when 'CA'
      return CAEntrySummaryGenerator.new
    else
      raise ArgumentError, "Invalid iso code of #{iso} specified."
    end
  end

  # US ONLY
  module DutyDetail
   
    def create_linked_digests(current_user, company)
      company.linked_companies.select{|co| co.importer?}.map{|co| create_digest(current_user, co)}.compact
    end

    def create_digest(current_user, company)
      build_digest(get_entries(current_user, company))
    end

    def build_digest(entries)
      co = nil
        entries.each do |ent|
          co ||= {company_name: ent.company_name, company_report: {date_hsh: {}, company_total_duty: 0, company_total_fees: 0, company_total_duty_and_fees: 0, company_entry_count: 0} }
          company_ptr = co[:company_report]
          date_ptr = company_ptr[:date_hsh][ent.duty_due_date] ||= {port_hsh: {}, date_total_duty: 0, date_total_fees: 0, date_total_duty_and_fees: 0, date_entry_count: 0}
          port_ptr = date_ptr[:port_hsh][ent.port_name] ||= {port_total_duty: 0, port_total_fees: 0, port_total_duty_and_fees: 0, port_entry_count: 0, entries: []}

          port_ptr[:port_total_duty] += ent.total_duty
          port_ptr[:port_total_fees] += ent.total_fees
          port_ptr[:port_total_duty_and_fees] += ent.total_duty_and_fees
          port_ptr[:port_entry_count] += 1
          port_ptr[:entries] << {ent_id: ent.entry_id, ent_entry_number: ent.entry_number, ent_entry_type: ent.entry_type, ent_port_name: ent.port_name, release_date_mf.uid => ent.send(release_date_mf.field_name), 
                                 ent_customer_references: ent.customer_references, ent_duty_due_date: ent.duty_due_date, ent_total_fees: ent.total_fees, 
                                 ent_total_duty: ent.total_duty, ent_total_duty_and_fees: ent.total_duty_and_fees}

          date_ptr[:date_total_duty] += ent.total_duty
          date_ptr[:date_total_fees] += ent.total_fees
          date_ptr[:date_total_duty_and_fees] += ent.total_duty_and_fees
          date_ptr[:date_entry_count] += 1

          company_ptr[:company_total_duty] += ent.total_duty
          company_ptr[:company_total_fees] += ent.total_fees
          company_ptr[:company_total_duty_and_fees] += ent.total_duty_and_fees
          company_ptr[:company_entry_count] += 1
        end
      co
    end
    
    def get_entries(current_user, company)
      if current_user.view_entries? && company.can_view?(current_user)
        Entry.search_secure(current_user, Entry.select("companies.name AS company_name, duty_due_date, ports.name AS port_name, entries.id AS entry_id, entry_number, "\
                                                       "entry_type, customer_references, #{ActiveRecord::Base.connection.quote_column_name(release_date_mf.field_name)}, total_duty, total_fees, (total_duty + total_fees) AS total_duty_and_fees")
                                               .joins(:us_entry_port)
                                               .joins(:importer)
                                               .where("importer_id = ? ", company.id)
                                               .where("#{ActiveRecord::Base.connection.quote_column_name(release_date_mf.field_name)} IS NOT NULL")
                                               .where("duty_due_date >= ?", Time.zone.now.in_time_zone(current_user.time_zone).to_date)
                                               .where(monthly_statement_due_date: nil)
                                               .order("duty_due_date"))                                        
      else []
      end
    end
  end

  # abstract summary builder, subclassed below for each country
  class EntrySummaryGenerator
    include OpenChain::Report::ReportHelper

    def release_date_mf
      raise "Method not implemented!"
    end

    def ocean_transport
      raise "Method not implemented!"
    end

    def air_transport
      raise "Method not implemented!"
    end

    def create_by_release_range_query company_id, range, base_date=Time.zone.now.midnight
      by_release_range_query company_id, base_date, range
    end

    def create_by_release_range_download company_id, range, base_date=Time.zone.now.midnight
      date_uid = (range == "holds") ? :ent_hold_date : release_date_mf.uid
      mf_uids = [:ent_entry_num,:ent_filed_date,date_uid,:ent_entered_value,:ent_customer_references,:ent_po_numbers,:ent_cust_name]
      select_clause = mf_uids.map { |uid| mf = ModelField.find_by_uid(uid); "#{mf.field_name} AS \"#{mf.label}\"" }.push("id AS \"Link\"").join(", ")
      qry = create_by_release_range_query(company_id, range, base_date).select(select_clause).to_sql
      wb, sheet = XlsMaker.create_workbook_and_sheet DETAILS[range]
      dt_lambda = datetime_translation_lambda(base_date.time_zone.name)
      table_from_query sheet, qry, {1 => dt_lambda, 2 => dt_lambda, "Link" => weblink_translation_lambda(CoreModule::ENTRY)}
      workbook_to_tempfile wb, "temp", file_name: "#{Company.find(company_id).name}_entry_detail.xls"
    end

    # build the hash with the elements that are common between both countries
    def generate_common_hash company_id, b_utc
      h = {}
      h['summary'] = {'1w'=>nil,'4w'=>nil,'open'=>nil}
      h['summary']['1w'] = generate_week_summary company_id, b_utc
      h['summary']['4w'] = generate_4week_summary company_id, b_utc
      h['summary']['holds'] = generate_hold_summary company_id
      h['summary']['open'] = generate_open_summary company_id, b_utc
      h['summary']['ytd'] = generate_ytd_summary company_id, b_utc
      h['by_port'] = generate_port_breakouts company_id, b_utc
      h['by_hts'] = generate_hts_breakouts company_id, b_utc
      h['vendors_ytd'] = generate_top_vendors company_id, b_utc 
      h['ports_ytd'] = generate_ports_ytd company_id, b_utc
      h
    end

    def by_release_range_query importer_id, base_date, range
      date_clause = nil
      base_date = base_date_utc base_date
      
      case range
      when '1w'
        date_clause = week_clause base_date
      when '4w'
        date_clause = four_week_clause base_date
      when 'holds'
        date_clause = "1=1"
        more_where_clauses = on_hold_clause
      when 'op'
        date_clause = not_released_clause base_date
      when 'ytd'
        date_clause = ytd_clause base_date
      else
        raise ArgumentError, "Invalid date range of #{range} specified. Valid values are '1w', '4w', 'op', 'ytd'."
      end
      
      Entry.where(date_clause)
           .where(Entry.search_where_by_company_id(importer_id))
           .where(tracking_open_clause)
           .where(country_clause)
           .where(format_where more_where_clauses)
           .order(%Q(IFNULL(entries.#{ActiveRecord::Base.connection.quote_column_name(release_date_mf.field_name)},"2999-01-01") DESC))
    end

    protected
    def timezone
      ActiveSupport::TimeZone['Eastern Time (US & Canada)']
    end

    private 
    def format_where clauses
      Array.wrap(clauses).join(' AND ').presence || "1=1"
    end
    def base_date_utc base_date
      timezone.local(base_date.year,base_date.month,base_date.day).utc
    end
    def generate_week_summary importer_id, base_date_utc
      generate_summary_line importer_id, week_clause(base_date_utc)
    end

    def generate_4week_summary importer_id, base_date_utc
      generate_summary_line importer_id, four_week_clause(base_date_utc)
    end

    def generate_hold_summary importer_id
      generate_summary_line importer_id, "1=1", on_hold_clause
    end

    def generate_open_summary importer_id, base_date_utc
      generate_summary_line importer_id, not_released_clause(base_date_utc)
    end

    def generate_ytd_summary importer_id, base_date_utc
      generate_summary_line importer_id, ytd_clause(base_date_utc) 
    end
    def generate_port_breakouts importer_id, base_date_utc
      generate_breakout_hash lambda {|imp,dc| generate_port_breakout_line(imp,dc)}, importer_id, base_date_utc 
    end

    def generate_ports_ytd importer_id, base_date_utc
      pbh = generate_port_breakout_line importer_id, ytd_clause(base_date_utc)
      r = []
      pbh.each do |p|
        r << {'name'=>p.first,'count'=>p.last['val'],'code'=>p.last['code']}
      end
      r.sort {|a,b| b['count'] <=> a['count']}
    end
    
    def generate_port_breakout_line importer_id, date_clause
      sql = "SELECT ports.name, ports.#{port_code_field}, count(*) 
      FROM entries
      INNER JOIN ports on ports.#{port_code_field} = entries.entry_port_code
      WHERE (#{Entry.search_where_by_company_id importer_id}) AND (#{date_clause})
      AND #{tracking_open_clause} AND #{country_clause}
      GROUP BY ports.name, ports.#{port_code_field}"
      r = {}
      ActiveRecord::Base.connection.execute(sql).each do |row|
        r[row.first] = {'code'=>row[1],'val'=>row.last}
      end
      r
    end

    def generate_breakout_hash query_lambda, importer_id, base_date_utc
      one_week = query_lambda.call(importer_id,week_clause(base_date_utc))
      four_week = query_lambda.call(importer_id,four_week_clause(base_date_utc))
      open = query_lambda.call(importer_id,not_released_clause(base_date_utc))
      names = (one_week.keys+four_week.keys+open.keys).uniq.sort
      tot_1 = 0
      tot_4 = 0
      tot_o = 0
      r = []
      names.each do |p|
        ow = one_week[p].blank? ? nil : one_week[p]['val']
        fw = four_week[p].blank? ? nil : four_week[p]['val']
        op = open[p].blank? ? nil : open[p]['val']
        cd = nil
        cd = one_week[p]['code'] unless ow.nil?
        cd ||= four_week[p]['code'] unless fw.nil?
        cd ||= open[p]['code'] unless op.nil?
        r << {'name'=>p,'1w'=>ow,'4w'=>fw,'open'=>op,'code'=>cd}
        tot_1 += ow unless ow.nil?
        tot_4 += fw unless fw.nil?
        tot_o += op unless op.nil?
      end
      r << {'name'=>'TOTAL','1w'=>tot_1,'4w'=>tot_4,'open'=>tot_o}
      r
    end
    def generate_hts_breakouts importer_id, base_date_utc
      generate_breakout_hash lambda {|imp,dc| generate_hts_breakout_line(imp,dc)}, importer_id, base_date_utc
    end
    def generate_hts_breakout_line importer_id, date_clause
      sql = "SELECT left(commercial_invoice_tariffs.hts_code,2), count(*) 
      FROM entries
      INNER JOIN commercial_invoices ON commercial_invoices.entry_id = entries.id
      INNER JOIN commercial_invoice_lines ON commercial_invoice_lines.commercial_invoice_id = commercial_invoices.id
      INNER JOIN commercial_invoice_tariffs ON commercial_invoice_tariffs.commercial_invoice_line_id = commercial_invoice_lines.id
      WHERE (#{Entry.search_where_by_company_id importer_id}) AND (#{date_clause})
      AND #{tracking_open_clause} AND #{country_clause}
      GROUP BY left(commercial_invoice_tariffs.hts_code,2)"
      r = {}
      ActiveRecord::Base.connection.execute(sql).each do |row|
        r[row.first] = {'code'=>row.first,'val'=>row.last}
      end
      r
    end
    def generate_top_vendors importer_id, base_date_utc
      sql = "SELECT #{vendor_field}, sum(commercial_invoice_tariffs.entered_value) 
      FROM entries
      INNER JOIN commercial_invoices ON commercial_invoices.entry_id = entries.id
      INNER JOIN commercial_invoice_lines ON commercial_invoice_lines.commercial_invoice_id = commercial_invoices.id
      INNER JOIN commercial_invoice_tariffs ON commercial_invoice_tariffs.commercial_invoice_line_id = commercial_invoice_lines.id
      WHERE (#{Entry.search_where_by_company_id importer_id}) 
      AND (#{ytd_clause(base_date_utc)}) 
      AND (#{tracking_open_clause}) AND #{country_clause}
      GROUP BY #{vendor_field} 
      ORDER BY sum(commercial_invoice_tariffs.entered_value) DESC
      LIMIT 5"
      r = []
      ActiveRecord::Base.connection.execute(sql).each do |row|
        r << {'name'=>row.first,'entered'=>row.last}
      end
      r
    end

    # generate a where clause for the previous 1 week 
    def week_clause base_date_utc
      ActiveRecord::Base.sanitize_sql_array(["(#{ActiveRecord::Base.connection.quote_column_name(release_date_mf.field_name)} > DATE_ADD(?,INTERVAL -1 WEEK) AND #{ActiveRecord::Base.connection.quote_column_name(release_date_mf.field_name)} < ?)", base_date_utc, end_of_day(base_date_utc)])
    end
    # generate a where clause for the previous 4 weeks
    def four_week_clause base_date_utc
      ActiveRecord::Base.sanitize_sql_array(["(#{ActiveRecord::Base.connection.quote_column_name(release_date_mf.field_name)} > DATE_ADD(?,INTERVAL -4 WEEK) AND #{ActiveRecord::Base.connection.quote_column_name(release_date_mf.field_name)} < ?)", base_date_utc, end_of_day(base_date_utc)])
    end
    # generate a where clause for open entries that are not released
    # "...AND entries.release_date IS NULL" is needed to prevent US entries released before we introduced first_release_received_date from being included.
    def not_released_clause base_date_utc
      ActiveRecord::Base.sanitize_sql_array(["((entries.#{ActiveRecord::Base.connection.quote_column_name(release_date_mf.field_name)} IS NULL AND entries.release_date IS NULL) OR entries.#{ActiveRecord::Base.connection.quote_column_name(release_date_mf.field_name)} > ?)", base_date_utc])
    end
    # genereate a where clause for Released Year to Date
    def ytd_clause base_date_utc
      ActiveRecord::Base.sanitize_sql_array(["(entries.#{ActiveRecord::Base.connection.quote_column_name(release_date_mf.field_name)} BETWEEN '?-01-01 00:00' AND '?-12-31 11:59:59.999')", base_date_utc.year.to_i, base_date_utc.year.to_i])
    end
    def end_of_day base_date_utc
      (base_date_utc + 1.day).midnight - 1.second
    end

    def tracking_open_clause
      ActiveRecord::Base.sanitize_sql_array(["(entries.tracking_status = ?)", Entry::TRACKING_STATUS_OPEN])
    end
    def country_clause
      ActiveRecord::Base.sanitize_sql_array(["(entries.import_country_id = ?)", country_id])
    end
    def on_hold_clause
      "entries.on_hold = true"
    end
  end
  # summary builder for Canadian entries
  class CAEntrySummaryGenerator < EntrySummaryGenerator
    def release_date_mf
      @release_date_mf ||= ModelField.find_by_uid :ent_release_date
    end

    def ocean_transport
      "9"
    end

    def air_transport
      "1, 6"
    end

    def generate_hash company_id, base_date
      @country_id = Country.find_by_iso_code('CA').id
      b_utc = base_date_utc base_date
      h = generate_common_hash company_id, b_utc
      h['k84'] = generate_k84_section company_id, b_utc
      h
    end

    def country_id
      @country_id ||= Country.find_by_iso_code('CA').id
      @country_id
    end

    def port_code_field
      'cbsa_port'
    end

    def vendor_field
      'commercial_invoices.vendor_name'
    end

    def generate_summary_line importer_id, date_clause, more_where_clauses=[]
      w = Entry.search_where_by_company_id importer_id
      sql = <<-SQL 
                 SELECT COUNT(*), SUM(total_duty), SUM(total_gst), SUM(entered_value), SUM(total_invoiced_value), SUM(total_units), SUM(total_duty_gst)
                 FROM entries 
                 WHERE (#{date_clause}) AND (#{w}) AND #{tracking_open_clause} AND #{country_clause} 
                   AND #{format_where more_where_clauses}
               SQL
      result_row = ActiveRecord::Base.connection.execute(sql).first
      {
        'count'=>result_row[0],
        'duty'=>result_row[1],
        'gst'=>result_row[2],
        'entered'=>result_row[3],
        'invoiced'=>result_row[4],
        'units'=>result_row[5],
        'duty_gst'=>result_row[6]
      }
    end
    def generate_k84_section importer_id, base_date_utc
      r = [] 
      qry = "
      select k84_due_date, sum(ifnull(total_duty_gst, 0)), importer_id, companies.name
from entries 
inner join companies on companies.id = entries.importer_id
where k84_due_date <= DATE(DATE_ADD('#{base_date_utc}',INTERVAL 1 MONTH) )
and k84_due_date >= DATE(DATE_ADD('#{base_date_utc}',INTERVAL -3 MONTH) )
and (#{Entry.search_where_by_company_id importer_id}) 
      AND #{tracking_open_clause} AND #{country_clause}
group by importer_id, k84_due_date
order by importer_id, k84_due_date desc"
      results = ActiveRecord::Base.connection.execute qry
      return r if results.first.nil? || results.first.first.nil?
      results.each do |row|
        r << {'due'=>row[0],'amount'=>row[1],'importer_name'=>row[3]}
      end
      r
    end
  end
  # summary builder for US entries
  class USEntrySummaryGenerator < EntrySummaryGenerator
    include OpenChain::ActivitySummary::DutyDetail

    def release_date_mf
      @release_date_mf ||= ModelField.find_by_uid :ent_first_release_received_date
    end

    def ocean_transport
      "10, 11"
    end

    def air_transport
      "40, 41"
    end

    def generate_hash company_id, base_date
      b_utc = base_date_utc base_date
      h = generate_common_hash company_id, b_utc
      h['pms'] = generate_pms_section company_id, b_utc
      h['unpaid_duty'] = generate_unpaid_duty_section Company.find(company_id), base_date
      h
    end

    def country_id
      @country_id ||= Country.find_by_iso_code('US').id
      @country_id
    end

    def generate_unpaid_duty_section importer, base_date_utc
      out = [single_company_unpaid_duty(importer, base_date_utc)]
      linked_companies_unpaid_duty(importer, base_date_utc).each {|co| out << co}
      out.flatten
    end

    def linked_companies_unpaid_duty importer, base_date_utc
      importer.linked_companies.select{|co| co.importer?}.map{ |co| single_company_unpaid_duty(co, base_date_utc)}
    end

    def single_company_unpaid_duty importer, base_date_utc
      Entry.select("customer_number, customer_name, Sum(entries.total_duty) AS total_duty, Sum(entries.total_fees) AS total_fees, "\
                   "Sum(entries.total_duty + entries.total_fees) AS total_duty_and_fees")
                  .where("entries.importer_id = #{importer.id}")
                  .where("#{release_date_mf.field_name} IS NOT NULL")
                  .where("duty_due_date >= ?", base_date_utc.to_date)
                  .where(monthly_statement_due_date: nil)
                  .group("customer_number")
    end

    private 
    def generate_pms_section importer_id, base_date_utc
      r = [] 
      qry = "
      select monthly_statement_due_date, monthly_statement_paid_date, sum(ifnull(total_duty, 0)) + sum(ifnull(total_fees, 0)) as 'Duty & Fees',
      importer_id, companies.name
from entries 
inner join companies on companies.id = entries.importer_id
where monthly_statement_due_date <= DATE(DATE_ADD('#{base_date_utc}',INTERVAL 1 MONTH)) 
and monthly_statement_due_date >= DATE(DATE_ADD('#{base_date_utc}',INTERVAL -3 MONTH)) 
and (#{Entry.search_where_by_company_id importer_id}) 
      AND #{tracking_open_clause} AND #{country_clause}
group by importer_id, monthly_statement_due_date, monthly_statement_paid_date
order by importer_id, monthly_statement_due_date desc"
      results = ActiveRecord::Base.connection.execute qry
      return r if results.first.nil? || results.first.first.nil?
      results.each do |row|
        r << {'due'=>row[0],'paid'=>row[1],'amount'=>row[2], 'importer_name'=>row[4]}
      end
      r
    end

    def port_code_field
      'schedule_d_code'
    end

    def vendor_field
      'commercial_invoice_lines.vendor_name'
    end

    def generate_summary_line importer_id, date_clause, more_where_clauses=[]
      w = Entry.search_where_by_company_id importer_id
      sql = <<-SQL 
                 SELECT COUNT(*), SUM(total_duty), SUM(total_fees), SUM(entered_value), SUM(total_invoiced_value), SUM(total_units)  
                 FROM entries 
                 WHERE (#{date_clause}) AND (#{w}) AND #{tracking_open_clause} AND #{country_clause}
                   AND #{format_where more_where_clauses}
               SQL
      result_row = ActiveRecord::Base.connection.execute(sql).first
      {
        'count'=>result_row[0],
        'duty'=>result_row[1],
        'fees'=>result_row[2],
        'entered'=>result_row[3],
        'invoiced'=>result_row[4],
        'units'=>result_row[5]
      }
    end
  end

  class EntrySummaryDownload
    include OpenChain::Report::ReportHelper
    attr_accessor :iso_code, :importer
    
    def self.permission? user, importer_id
      Entry.can_view_importer?(Company.find(importer_id),user)
    end

    def self.run_report run_by, settings={}
      self.new(settings['importer_id'], settings['iso_code'], run_by.try(:time_zone)).run
    end

    # required args: system_code (or alliance_customer_number or fenix_customer_number), iso_code, email 
    def self.run_schedulable settings={}
      iso = settings['iso_code'].upcase
      imp = find_company settings
      email_report imp, iso, settings["email"], nil, nil, nil, settings["mailing_list"]
    end

    def self.email_report importer, iso_code, addresses, subject=nil, body=nil, user_id=nil, mailing_list=nil
      ReportEmailer.email importer, iso_code, addresses, subject, body, user_id, mailing_list
    end

    class ReportEmailer
      def self.email importer, iso_code, addresses, subject=nil, body=nil, user_id=nil, mailing_list=nil
        gen = OpenChain::ActivitySummary::EntrySummaryDownload.new importer, iso_code
        addresses, subject, body = update_args(gen, addresses, subject, body, user_id)
        begin
          report = gen.run
          to = []
          to << addresses unless addresses.blank?
          mailing_list = MailingList.where(id: mailing_list).first unless mailing_list.nil?
          to << mailing_list unless mailing_list.nil?
          OpenMailer.send_simple_html(to, subject, body, [report]).deliver_now
        ensure
          report.close
        end
      end
      
      def self.update_args generator, addresses, subject, body, user_id
        today = generator.now.to_date.strftime('%Y-%m-%d')
        default_subject = "#{generator.importer.name} #{generator.iso_code} entry summary for #{today}"
        subject = default_subject unless subject.present?
        body = "#{default_subject} is attached." unless body.present?
        addresses, body = update_args_with_user(addresses, body, user_id) if user_id
        [addresses, subject, body]
      end

      def self.update_args_with_user addresses, body, user_id
        user = User.find_by_id user_id
        if addresses.blank?
          addresses = user.email 
        else
          body = "<p>#{user.first_name} #{user.last_name} (#{user.email}) has sent you a report.</p><br>".html_safe + body
        end
        [addresses, body]
      end
    end

    # Because Axlsx (and therefore XlsxBuilder) doesn't allow random access to rows, data is written here first.
    class DrawingBoard
      attr_reader :rows
      
      def initialize
        @rows = []
      end

      def insert_row row_number, starting_col_number, row_data, styles = [], merged_cells = []
        row = @rows[row_number] || {data: [], styles: [], merged_cells: []}
        ending_col_number = starting_col_number + row_data.count
        
        row[:data][starting_col_number...ending_col_number] = row_data
        row[:styles][starting_col_number...ending_col_number] = styles.presence || Array.new(row_data.count, nil)
        row[:merged_cells][starting_col_number...ending_col_number] = merged_cells.presence || Array.new(row_data.count, nil)
        @rows[row_number] = row
        
        nil
      end
    end

    def self.find_company settings
      if settings['system_code']
        return Company.where(system_code: settings['system_code']).first
      elsif settings['iso_code'].upcase == "US"
        if settings["cargowise_customer_number"].blank?
          return Company.find_by_system_code("Customs Management", settings["alliance_customer_number"])
        else
          return Company.find_by_system_code("Cargowise", settings["cargowise_customer_number"])
        end
      else
        return Company.find_by_system_code("Fenix", settings["fenix_customer_number"])
      end
    end

    def initialize importer_or_id, iso_code, time_zone=nil
      @importer = importer_or_id.is_a?(Company) ? importer_or_id : Company.find(importer_or_id)
      @iso_code = iso_code.upcase
      @time_zone = time_zone
      @row_num = MutableNumber.new 0
    end
    
    def run
      us_meth = :generate_us_entry_summary
      ca_meth = :generate_ca_entry_summary
      summary = OpenChain::ActivitySummary.send(us? ? us_meth : ca_meth, importer.id)
      convert_to_spreadsheet summary['activity_summary']
    end

    def now
      Time.zone.now.in_time_zone(@time_zone || "Eastern Time (US & Canada)")
    end
    
    def row_num= n
      @row_num.value = n
    end

    def row_num
      @row_num.value
    end

    def us?
      iso_code == "US"
    end

    def fst_col
      0
    end

    def snd_col
      us? ? 5 : 6
    end

    def activity_summary_url
      hlp = Rails.application.routes.url_helpers
      us_meth = :entries_activity_summary_us_with_importer_path
      ca_meth = :entries_activity_summary_ca_with_importer_path
      XlsMaker.excel_url hlp.send(us? ? us_meth : ca_meth, importer.id)
    end

    def convert_to_spreadsheet summary
      imp_name = importer.name
      wb = XlsxBuilder.new
      assign_styles wb
      sheet = wb.create_sheet "Summary"
      write_xlsx wb, sheet, summary
      xlsx_workbook_to_tempfile wb, "temp", file_name: "#{imp_name}_entry_detail.xlsx"
    end

    def assign_styles wb
      wb.create_style :bold, {b: true}
      wb.create_style :right_header, {b: true, alignment: {horizontal: :right}}
      wb.create_style :centered_header, {b: true, alignment: {horizontal: :center}}
    end

    def write_xlsx wb, sheet, summary
      board = DrawingBoard.new
      write_header board
      write_summary_header board
      write_summary_body board, summary['summary']
      # FIRST COLUMN
      self.row_num = 12
      if us?
        write_pms board, summary['pms'], (self.row_num += 3) if summary['pms'].present?
        write_unpaid_duty board, summary['unpaid_duty'], (self.row_num += 3) if summary['unpaid_duty'].present?
      else
        write_k84 board, summary['k84'], (self.row_num += 3)
      end
      write_breakouts board, summary, (self.row_num += 3)
      write_linked_companies board, (self.row_num += 3)
      # SECOND COLUMN
      self.row_num = 12
      write_released_ytd board, summary, (self.row_num += 3)
      transcribe wb, sheet, board
      wb.set_column_widths sheet, 40, 20, 20, 20, 20, 20, 20,20
      wb.add_image sheet, "app/assets/images/vfi_track_logo.png", 198, 59, 4, 2
      nil
    end

    def transcribe wb, sheet, board
      board.rows.each do |row|
        if row
          merged_cells = Array.wrap(merged_cell_array_to_range row)
          wb.add_body_row sheet, row[:data], {styles: row[:styles], merged_cell_ranges: merged_cells}
        else
          wb.add_body_row sheet, [nil]
        end
      end

      nil
    end

    def merged_cell_array_to_range row
      merged_cells = []
      row[:merged_cells].each_with_index { |mc, idx| merged_cells << (mc ? idx : nil) }
      # partition numeric sequences with nils, e.g. [1,2,3,nil,nil,4,5,6] => [[1,2,3],[4,5,6]]
      merged_cells = merged_cells.chunk{ |mc| !mc.nil?}.select{ |mc| mc.first == true }.map(&:last)
      merged_cells.map{ |mc| Range.new(mc.first, mc.last) }
    end

    def write_header board
      board.insert_row 0, 0, ["Vandegrift VFI Track Insights"] + Array.new(us? ? 6 : 7, nil), Array.new(us? ? 7 : 8, :default_header), Array.new(us? ? 7 : 8, true)
      board.insert_row 1, 0, ["#{iso_code} Entry Activity"], [:bold]
      board.insert_row 2, 0, ["Date", now]
      board.insert_row 3, 0, ["Customer Number", importer.system_code.presence || (us? ? (importer.kewill_customer_number.presence? || importer.cargowise_customer_number) : importer.fenix_customer_number)]
      board.insert_row 4, 0, ["View Summary in Real Time", {type: :hyperlink, link_text: "Link", location: activity_summary_url}]
    end

    def write_summary_header board
      us_headers = ["# of Entries", "Duty", "Fees", "Entered Value", "Invoiced Value", "Units"]
      ca_headers = ["# of Entries", "Duty", "GST", "Duty/GST", "Entered Value", "Invoiced Value", "Units"]
      board.insert_row 7, 0, ["Summary"] + Array.new(us? ? 6 : 7, nil), Array.new(us? ? 7 : 8, :default_header), Array.new(us? ? 7 : 8, true)
      board.insert_row 8, 1, us? ? us_headers : ca_headers, Array.new(us? ? 7 : 8, :bold)
    end

    def write_summary_body board, sum
      board.insert_row 9,  0, summary_fields("Released Last 7 Days", sum['1w']), summary_formats
      board.insert_row 10, 0, summary_fields("Released Last 28 Days", sum['4w']), summary_formats
      board.insert_row 11, 0, summary_fields("Filed / Not Released", sum['open']), summary_formats
      board.insert_row 12, 0, summary_fields("Entries On Hold", sum['holds']), summary_formats
    end

    def summary_fields heading, row
      if us?
        [heading, row['count'], row['duty'], row['fees'], row['entered'], row['invoiced'], row['units']]
      else
        [heading, row['count'], row['duty'], row['gst'], row['duty_gst'], row['entered'], row['invoiced'], row['units']]
      end
    end

    def summary_formats
      if us?
        [nil, nil] + Array.new(4, :default_currency) + [nil]
      else
        [nil, nil] + Array.new(5, :default_currency) + [nil]
      end
    end

    def write_pms board, rows, row_num
      board.insert_row row_num, fst_col, ["Periodic Monthly Statement",nil,nil,nil], Array.new(4, :default_header), Array.new(4, true)
      board.insert_row (self.row_num += 1), fst_col, ["Company", "Due", "Paid", "Amount"], Array.new(4, :bold)
      rows.each { |r| board.insert_row (self.row_num += 1), fst_col, [r['importer_name'], r['due'], r['paid'], r['amount']], [nil,nil,nil,:default_currency] }
    end
      
    def write_k84 board, rows, row_num
      board.insert_row row_num, fst_col, ["Estimated K84 Statement",nil,nil], Array.new(3, :default_header), Array.new(3, true)
      board.insert_row (self.row_num += 1), fst_col, ["Name", "Due", "Amount"], Array.new(3, :bold)
      rows.each { |r| board.insert_row (self.row_num += 1), fst_col, [r['importer_name'], r['due'], r['amount']], [nil,nil,:default_currency] }
    end

    def write_unpaid_duty board, rows, row_num
      board.insert_row row_num, fst_col, ["Unpaid Duty",nil,nil,nil], Array.new(4, :default_header), Array.new(4, true)
      board.insert_row (self.row_num += 1), fst_col, ["Company", "Total Duty", "Total Fees", "Total Duty and Fees"], Array.new(4, :bold)
      rows.each { |r| board.insert_row (self.row_num += 1), fst_col, [r['customer_name'].upcase, r['total_duty'], r['total_fees'], r['total_duty_and_fees']], [nil] + Array.new(3, :default_currency) }
    end

    def write_breakouts board, sum, row_num
      board.insert_row row_num, fst_col, ["Entry Breakouts",nil,nil,nil], Array.new(4, :default_header), Array.new(4, true)      
      write_ent_ports board, sum["by_port"], (self.row_num += 1)
      write_lines_by_chpt board, sum["by_hts"], (self.row_num +=2 )
    end

    def write_ent_ports board, rows, row_num
      board.insert_row row_num, fst_col, ["Entries by Port",nil,nil,nil], Array.new(4, :centered_header), Array.new(4, true)
      board.insert_row (self.row_num += 1) , fst_col, ["Port", "1 Week", "4 Weeks", "Open"], Array.new(4, :bold)
      rows.each { |r| board.insert_row (self.row_num += 1), fst_col, [r['name'], r['1w'], r['4w'], r['open']] }
    end

    def write_lines_by_chpt board, rows, row_num
      board.insert_row row_num, fst_col, ["Lines by Chapter",nil,nil,nil], Array.new(4, :centered_header), Array.new(4, true)
      board.insert_row (self.row_num += 1) , fst_col, ["Chapter", "1 Week", "4 Weeks", "Open"], Array.new(4, :bold)
      rows.each { |r| board.insert_row (self.row_num += 1), fst_col, [r['name'], r['1w'], r['4w'], r['open']] }
    end

    def write_released_ytd board, sum, row_num
      board.insert_row row_num, snd_col, ["Released Year To Date",nil], Array.new(2, :default_header), Array.new(2, true)
      write_ytd_summary board, sum['summary']['ytd'], (self.row_num += 1)
      write_ytd_top_5 board, sum['vendors_ytd'], (self.row_num += 2)
      write_ytd_ports board, sum['ports_ytd'], (self.row_num += 2)
    end

    def write_ytd_summary board, rows, row_num
      board.insert_row row_num, snd_col, ["Summary",nil], Array.new(2, :centered_header), Array.new(2, true)
      board.insert_row (self.row_num += 1), snd_col, ["Entries", rows['count']]
      board.insert_row (self.row_num += 1), snd_col, ["Duty", rows['duty']], [nil, :default_currency]
      if us?
        board.insert_row (self.row_num += 1), snd_col, ["Fees", rows['fees']], [nil, :default_currency] 
      else
        board.insert_row (self.row_num += 1), snd_col, ["GST", rows['gst']], [nil, :default_currency] 
        board.insert_row (self.row_num += 1), snd_col, ["Duty/GST", rows['duty_gst']], [nil, :default_currency] 
      end
      board.insert_row (self.row_num += 1), snd_col, ["Entered Value", rows['entered']], [nil, :default_currency]
      board.insert_row (self.row_num += 1), snd_col, ["Invoiced Value", rows['invoiced']], [nil, :default_currency]
      board.insert_row (self.row_num += 1), snd_col, ["Units", rows['units']]
    end

    def write_ytd_top_5 board, rows, row_num
      board.insert_row row_num, snd_col, ["Top 5 Vendors",nil], Array.new(2, :centered_header), Array.new(2, true)
      board.insert_row (self.row_num += 1), (snd_col + 1), ["Entered Value"], [:right_header]
      rows.each { |r| board.insert_row (self.row_num += 1), snd_col, [r['name'], r['entered']],[nil, :default_currency] }
    end

    def write_ytd_ports board, rows, row_num
      board.insert_row row_num, snd_col, ["Ports",nil], Array.new(2, :centered_header), Array.new(2, true)
      board.insert_row (self.row_num += 1), (snd_col + 1), ["Shipments"], [:right_header]
      rows.each { |r| board.insert_row (self.row_num += 1), snd_col, [r['name'], r['count']] }
    end

    def write_linked_companies board, row_num
      board.insert_row row_num, fst_col, ["Companies Included",nil,nil,nil], Array.new(4, :default_header), Array.new(4, true)

      ([importer] + importer.linked_companies.to_a).each do |lc|
        customs_id = lc.customs_identifier
        next if lc != importer && customs_id.blank?

        board.insert_row (self.row_num += 1), fst_col, ["#{lc.name} (#{customs_id})"]
      end
    end
  end

end; end
