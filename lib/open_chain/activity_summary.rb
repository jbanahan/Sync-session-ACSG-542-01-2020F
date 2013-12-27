module OpenChain; class ActivitySummary

  def self.generate_entry_summary company_id, base_date=0.days.ago.to_date
    {'activity_summary'=>USEntrySummaryGenerator.generate_hash(company_id, base_date)}
  end

  class USEntrySummaryGenerator
    EST = ActiveSupport::TimeZone['Eastern Time (US & Canada)']
    def self.generate_hash company_id, base_date
      b_utc = base_date_utc base_date
      h = {}
      h['summary'] = {'1w'=>nil,'4w'=>nil,'open'=>nil}
      h['summary']['1w'] = generate_week_summary company_id, b_utc
      h['summary']['4w'] = generate_4week_summary company_id, b_utc
      h['summary']['open'] = generate_open_summary company_id, b_utc
      h['summary']['ytd'] = generate_ytd_summary company_id, b_utc
      h['pms'] = generate_pms_section company_id, b_utc
      h['by_port'] = generate_port_breakouts company_id, b_utc
      h['by_hts'] = generate_hts_breakouts company_id, b_utc
      h['vendors_ytd'] = generate_top_vendors company_id, b_utc 
      h['ports_ytd'] = generate_ports_ytd company_id, b_utc
      h
    end

    private 
    def self.generate_pms_section importer_id, base_date_utc
      r = [] 
      qry = "
      select monthly_statement_due_date, monthly_statement_paid_date, sum(total_duty) + sum(total_fees) as 'Duty & Fees' 
from entries where monthly_statement_due_date <= DATE_ADD('#{base_date_utc}',INTERVAL 30 DAY) 
and (#{Entry.search_where_by_company_id importer_id}) and (#{Entry.import_country_clause 'US'})
group by monthly_statement_due_date, monthly_statement_paid_date
order by monthly_statement_due_date desc
limit 3"
      results = ActiveRecord::Base.connection.execute qry
      return r if results.first.nil? || results.first.first.nil?
      results.each do |row|
        r << {'due'=>row[0],'paid'=>row[1],'amount'=>row[2]}
      end
      r
    end

    def self.generate_port_breakouts importer_id, base_date_utc
      generate_breakout_hash lambda {|imp,dc| generate_port_breakout_line(imp,dc)}, importer_id, base_date_utc 
    end

    def self.generate_ports_ytd importer_id, base_date_utc
      pbh = generate_port_breakout_line importer_id, ytd_clause(base_date_utc)
      r = []
      pbh.each do |p|
        r << {'name'=>p.first,'count'=>p.last['val'],'code'=>p.last['code']}
      end
      r.sort {|a,b| b['count'] <=> a['count']}
    end
    
    def self.generate_port_breakout_line importer_id, date_clause
      sql = "SELECT ports.name, ports.schedule_d_code, count(*) 
      FROM entries
      INNER JOIN ports on ports.schedule_d_code = entries.entry_port_code
      WHERE (#{Entry.search_where_by_company_id importer_id}) AND (#{date_clause}) and (#{Entry.import_country_clause 'US'})
      GROUP BY ports.name, ports.schedule_d_code"
      r = {}
      ActiveRecord::Base.connection.execute(sql).each do |row|
        r[row.first] = {'code'=>row[1],'val'=>row.last}
      end
      r
    end

    def self.generate_hts_breakouts importer_id, base_date_utc
      generate_breakout_hash lambda {|imp,dc| generate_hts_breakout_line(imp,dc)}, importer_id, base_date_utc
    end
    def self.generate_hts_breakout_line importer_id, date_clause
      sql = "SELECT left(commercial_invoice_tariffs.hts_code,2), count(*) 
      FROM entries
      INNER JOIN commercial_invoices ON commercial_invoices.entry_id = entries.id
      INNER JOIN commercial_invoice_lines ON commercial_invoice_lines.commercial_invoice_id = commercial_invoices.id
      INNER JOIN commercial_invoice_tariffs ON commercial_invoice_tariffs.commercial_invoice_line_id = commercial_invoice_lines.id
      WHERE (#{Entry.search_where_by_company_id importer_id}) AND (#{date_clause}) and (#{Entry.import_country_clause 'US'})
      GROUP BY left(commercial_invoice_tariffs.hts_code,2)"
      r = {}
      ActiveRecord::Base.connection.execute(sql).each do |row|
        r[row.first] = {'code'=>row.first,'val'=>row.last}
      end
      r
    end

    def self.generate_breakout_hash query_lambda, importer_id, base_date_utc
      one_week = query_lambda.call(importer_id,week_clause(base_date_utc))
      four_week = query_lambda.call(importer_id,four_week_clause(base_date_utc))
      open = query_lambda.call(importer_id,open_clause(base_date_utc))
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

    def self.generate_top_vendors importer_id, base_date_utc
      sql = "SELECT commercial_invoice_lines.vendor_name, sum(commercial_invoice_tariffs.entered_value) 
      FROM entries
      INNER JOIN commercial_invoices ON commercial_invoices.entry_id = entries.id
      INNER JOIN commercial_invoice_lines ON commercial_invoice_lines.commercial_invoice_id = commercial_invoices.id
      INNER JOIN commercial_invoice_tariffs ON commercial_invoice_tariffs.commercial_invoice_line_id = commercial_invoice_lines.id
      WHERE (#{Entry.search_where_by_company_id importer_id}) AND (#{ytd_clause(base_date_utc)}) and (#{Entry.import_country_clause 'US'})
      GROUP BY commercial_invoice_lines.vendor_name
      ORDER BY sum(commercial_invoice_tariffs.entered_value) DESC
      LIMIT 5"
      r = []
      ActiveRecord::Base.connection.execute(sql).each do |row|
        r << {'name'=>row.first,'entered'=>row.last}
      end
      r
    end

    def self.generate_week_summary importer_id, base_date_utc
      generate_summary_line importer_id, week_clause(base_date_utc)
    end

    def self.generate_4week_summary importer_id, base_date_utc
      generate_summary_line importer_id, four_week_clause(base_date_utc)
    end

    def self.generate_open_summary importer_id, base_date_utc
      generate_summary_line importer_id, open_clause(base_date_utc)
    end

    def self.generate_ytd_summary importer_id, base_date_utc
      generate_summary_line importer_id, ytd_clause(base_date_utc) 
    end

    def self.generate_summary_line importer_id, date_clause
      w = Entry.search_where_by_company_id importer_id
      sql = "select count(*), sum(total_duty), sum(total_fees), sum(entered_value), sum(total_invoiced_value), sum(total_units)  from entries 
      where (#{date_clause}) AND (#{w}) and (#{Entry.import_country_clause 'US'})"
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
    
    # generate a where clause for the previous 1 week 
    def self.week_clause base_date_utc
      Entry.week_clause base_date_utc
    end
    # generate a where clause for the previous 4 weeks
    def self.four_week_clause base_date_utc
      Entry.four_week_clause base_date_utc
    end
    # generate a where clause for open entries
    def self.open_clause base_date_utc
      Entry.open_clause base_date_utc
    end
    # genereate a where clause for Year to Date
    def self.ytd_clause base_date_utc
      Entry.ytd_clause base_date_utc 
    end
    def self.base_date_utc base_date
      EST.local(base_date.year,base_date.month,base_date.day).utc
    end
  end
end; end
