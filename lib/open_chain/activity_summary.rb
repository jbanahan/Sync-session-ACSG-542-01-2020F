module OpenChain; class ActivitySummary

  def self.generate_us_entry_summary company_id, base_date=Time.zone.now.midnight
    {'activity_summary'=>generator_for_country("US").generate_hash(company_id, base_date)}
  end
  def self.generate_ca_entry_summary company_id, base_date=Time.zone.now.midnight
    {'activity_summary'=>generator_for_country("CA").generate_hash(company_id, base_date)}
  end

  def self.create_by_release_range_query company_id, country_iso, range, base_date=Time.zone.now.midnight
    generator_for_country(country_iso).by_release_range_query company_id, base_date, range
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
  private_class_method :generator_for_country

  # abstract summary builder, subclassed below for each country
  class EntrySummaryGenerator

    # build the hash with the elements that are common between both countries
    def generate_common_hash company_id, b_utc
      h = {}
      h['summary'] = {'1w'=>nil,'4w'=>nil,'open'=>nil}
      h['summary']['1w'] = generate_week_summary company_id, b_utc
      h['summary']['4w'] = generate_4week_summary company_id, b_utc
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
    end

    protected
      def timezone
        ActiveSupport::TimeZone['Eastern Time (US & Canada)']
      end

    private 
    def base_date_utc base_date
      timezone.local(base_date.year,base_date.month,base_date.day).utc
    end
    def generate_week_summary importer_id, base_date_utc
      generate_summary_line importer_id, week_clause(base_date_utc)
    end

    def generate_4week_summary importer_id, base_date_utc
      generate_summary_line importer_id, four_week_clause(base_date_utc)
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
      "(release_date > DATE_ADD('#{base_date_utc}',INTERVAL -1 WEEK) and release_date < '#{end_of_day(base_date_utc)}')"
    end
    # generate a where clause for the previous 4 weeks
    def four_week_clause base_date_utc
      "(release_date > DATE_ADD('#{base_date_utc}',INTERVAL -4 WEEK) and release_date < '#{end_of_day(base_date_utc)}')"
    end
    # generate a where clause for open entries that are not released
    def not_released_clause base_date_utc
      "(entries.release_date is null OR entries.release_date > '#{base_date_utc}')"
    end
    # genereate a where clause for Year to Date
    def ytd_clause base_date_utc
      "((entries.release_date IS NULL OR entries.release_date > '#{base_date_utc}') OR (entries.release_date >= '#{base_date_utc.year}-01-01' AND release_date <= '#{end_of_day(base_date_utc)}'))"
    end
    def end_of_day base_date_utc
      (base_date_utc + 1.day).midnight - 1.second
    end

    def tracking_open_clause
      "(entries.tracking_status = #{Entry::TRACKING_STATUS_OPEN})"
    end
    def country_clause
      "(entries.import_country_id = #{country_id})"
    end
  end
  # summary builder for Canadian entries
  class CAEntrySummaryGenerator < EntrySummaryGenerator
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

    def generate_summary_line importer_id, date_clause
      w = Entry.search_where_by_company_id importer_id
      sql = "select count(*), sum(total_duty), sum(total_gst), sum(entered_value), sum(total_invoiced_value), sum(total_units), sum(total_duty_gst) 
      from entries 
      where (#{date_clause}) AND (#{w}) AND #{tracking_open_clause} AND #{country_clause}"
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
where k84_due_date <= DATE_ADD('#{base_date_utc}',INTERVAL 1 MONTH) 
and k84_due_date >= DATE_ADD('#{base_date_utc}',INTERVAL -3 MONTH) 
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
    def generate_hash company_id, base_date
      b_utc = base_date_utc base_date
      h = generate_common_hash company_id, b_utc
      h['pms'] = generate_pms_section company_id, b_utc
      h
    end

    def country_id
      @country_id ||= Country.find_by_iso_code('US').id
      @country_id
    end

    private 
    def generate_pms_section importer_id, base_date_utc
      r = [] 
      qry = "
      select monthly_statement_due_date, monthly_statement_paid_date, sum(ifnull(total_duty, 0)) + sum(ifnull(total_fees, 0)) as 'Duty & Fees',
      importer_id, companies.name
from entries 
inner join companies on companies.id = entries.importer_id
where monthly_statement_due_date <= DATE_ADD('#{base_date_utc}',INTERVAL 1 MONTH) 
and monthly_statement_due_date >= DATE_ADD('#{base_date_utc}',INTERVAL -3 MONTH) 
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

    def generate_summary_line importer_id, date_clause
      w = Entry.search_where_by_company_id importer_id
      sql = "select count(*), sum(total_duty), sum(total_fees), sum(entered_value), sum(total_invoiced_value), sum(total_units)  from entries 
      where (#{date_clause}) AND (#{w}) AND #{tracking_open_clause} AND #{country_clause}"
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
end; end
