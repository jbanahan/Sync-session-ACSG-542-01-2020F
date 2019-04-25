require 'open_chain/report/report_helper'

module OpenChain; module Report; class CustomerYearOverYearReport
  include OpenChain::Report::ReportHelper

  ENTRY_YEAR_OVER_YEAR_REPORT_USERS ||= 'entry_yoy_report'

  YearOverYearData ||= Struct.new(:range_year,:range_month,:customer_number,:customer_name,:broker_reference,
                                       :entry_line_count,:entry_type,:entered_value,:total_duty,:mpf,:hmf,:cotton_fee,
                                       :total_taxes,:other_fees,:total_fees,:arrival_date,:release_date,
                                       :file_logged_date,:fiscal_date,:eta_date,:total_units,:total_gst,
                                       :export_country_codes,:transport_mode_code,:broker_invoice_total,
                                       :entry_type_count_hash,:entry_count,:isf_fees,:mode_of_transportation_count_hash,
                                       :entry_port_code) do
    def initialize
      self.entry_count ||= 0
      self.entry_line_count ||= 0
      self.entered_value ||= 0.00
      self.total_duty ||= 0.00
      self.mpf ||= 0.00
      self.hmf ||= 0.00
      self.cotton_fee ||= 0.00
      self.total_taxes ||= 0.00
      self.other_fees ||= 0.00
      self.total_fees ||= 0.00
      self.total_units ||= 0.00
      self.total_gst ||= 0.00
      self.broker_invoice_total ||= 0.00
      self.isf_fees ||= 0.00
      self.entry_type_count_hash ||= {}
      self.mode_of_transportation_count_hash ||= {}
    end

    def total_duty_and_fees
      total_duty + total_fees
    end
  end

  def self.permission? user
    user.view_entries? && MasterSetup.get.custom_feature?("Entry Year Over Year Report") && user.in_group?(Group.use_system_group(ENTRY_YEAR_OVER_YEAR_REPORT_USERS, create: false))
  end

  def self.run_report run_by, settings
    self.new.run_year_over_year_report settings
  end

  def self.run_schedulable settings={}
    raise "Email address is required." if settings['email'].blank?
    self.new.run_year_over_year_report settings
  end

  def run_year_over_year_report settings
    year_1, year_2 = get_years settings

    mode_of_transport_codes = get_transport_mode_codes settings['mode_of_transport']

    importer_ids = settings['importer_ids']
    range_field = get_range_field settings
    workbook = nil
    distribute_reads do
      workbook = generate_report importer_ids, year_1, year_2, range_field, settings['include_cotton_fee'], settings['include_taxes'], settings['include_other_fees'], settings['include_isf_fees'], mode_of_transport_codes, settings['include_port_breakdown'], settings['group_by_mode_of_transport'], settings['entry_types'], settings['include_line_graphs']
    end

    system_code = importer_ids.length == 1 ? Company.find(importer_ids[0]).try(:system_code).to_s : 'MULTI'
    file_name = "Entry_YoY_#{system_code}_#{range_field}_[#{year_1}_#{year_2}].xlsx"
    if settings['email'].present?
      workbook_to_tempfile workbook, "YoY Report", file_name: "#{file_name}" do |temp|
        OpenMailer.send_simple_html(settings['email'], "#{system_code} YoY Report #{year_1} vs. #{year_2}", "A year-over-year report is attached, comparing #{year_1} and #{year_2}.", temp).deliver!
      end
    else
      workbook_to_tempfile(workbook, "YoY Report", file_name: "#{file_name}")
    end
  end

  private
    # Pull year values from the settings, or default if none are provided.
    def get_years settings
      # Default to previous year if year_1 value is not provided.
      year_1 = settings['year_1'].to_i
      if year_1 == 0
        year_1 = Date.today.year - 1
      end

      # Default to current year if year_2 value is not provided.
      year_2 = settings['year_2'].to_i
      if year_2 == 0
        year_2 = Date.today.year
      end

      # Swap the years if the first year is greater than the second.  Always have the later year occur second in the report output.
      if year_1 > year_2
        temp_year = year_1
        year_1 = year_2
        year_2 = temp_year
      end
      [year_1, year_2]
    end

    def get_transport_mode_codes modes_param
      mode_of_transport_codes = []
      modes_param.try(:each) {|mode| Entry.get_transport_mode_codes_us_ca(mode).each {|i| mode_of_transport_codes << i }}
      mode_of_transport_codes
    end

    # Pulls the range field from the settings, allowing only certain values so as to bypass potential SQL injection
    # issues.  Because of the way these queries are written (this is a dynamic field in the query, not a value for
    # a field), simply sanitizing the settings value is inadequate.
    def get_range_field settings
      range_field = settings['range_field']
      # Defaults to arrival date if bad.  This is the default value on screen.
      ['arrival_date','eta_date','file_logged_date','fiscal_date','release_date'].include?(range_field) ? range_field : "arrival_date"
    end

    def generate_report importer_ids, year_1, year_2, range_field, include_cotton_fee, include_taxes, include_other_fees, include_isf_fees, mode_of_transport_codes, include_port_breakdown, group_by_mode_of_transport, entry_types, include_line_graphs
      wb = XlsxBuilder.new
      assign_styles wb

      raw_data = []
      result_set = ActiveRecord::Base.connection.exec_query make_query(importer_ids, year_1, year_2, range_field, mode_of_transport_codes, entry_types)
      result_set.each do |result_set_row|
        d = YearOverYearData.new
        if range_field_is_datetime range_field
          d.range_year = result_set_row['range_year_tz_converted']
          d.range_month = result_set_row['range_month_tz_converted']
        else
          d.range_year = result_set_row['range_year']
          d.range_month = result_set_row['range_month']
        end
        d.customer_number = result_set_row['customer_number']
        d.customer_name = result_set_row['customer_name']
        d.broker_reference = result_set_row['broker_reference']
        d.entry_line_count = result_set_row['entry_line_count']
        d.entry_type = result_set_row['entry_type']
        d.entered_value = result_set_row['entered_value']
        d.total_duty = result_set_row['total_duty']
        d.mpf = result_set_row['mpf']
        d.hmf = result_set_row['hmf']
        d.cotton_fee = result_set_row['cotton_fee']
        d.total_taxes = result_set_row['total_taxes']
        d.other_fees = result_set_row['other_fees']
        d.total_fees = result_set_row['total_fees']
        d.arrival_date = result_set_row['arrival_date']
        d.release_date = result_set_row['release_date']
        d.file_logged_date = result_set_row['file_logged_date']
        d.fiscal_date = result_set_row['fiscal_date']
        d.eta_date = result_set_row['eta_date']
        d.total_units = result_set_row['total_units']
        d.total_gst = result_set_row['total_gst']
        d.export_country_codes = result_set_row['export_country_codes']
        d.transport_mode_code = result_set_row['transport_mode_code']
        d.broker_invoice_total = result_set_row['broker_invoice_total']
        d.isf_fees = result_set_row['isf_fees']
        d.entry_port_code = result_set_row['entry_port_code']
        raw_data << d
      end

      generate_summary_sheet wb, importer_ids, year_1, year_2, include_cotton_fee, include_taxes, include_other_fees, include_isf_fees, raw_data, group_by_mode_of_transport, include_line_graphs
      generate_data_sheet wb, raw_data

      if include_port_breakdown
        generate_port_breakdown_sheet wb, importer_ids, range_field, include_cotton_fee, include_taxes, include_other_fees, include_isf_fees, mode_of_transport_codes, entry_types
      end

      wb
    end

    def assign_styles wb
      wb.create_style :bold, {b: true}
      wb.create_style(:currency, {format_code: "$#,##0.00"})
      wb.create_style(:number, {format_code: "#,##0"})
    end

    # This sheet contains data summarized by month and year.
    def generate_summary_sheet wb, importer_ids, year_1, year_2, include_cotton_fee, include_taxes, include_other_fees, include_isf_fees, data_arr, group_by_mode_of_transport, include_line_graphs
      company_name = importer_ids.length == 1 ? Company.find(importer_ids[0]).try(:name) : "MULTI COMPANY"
      # Handling long company names: some versions of Excel allow only 30 characters for tab names, so, because of the
      # 9-char suffix tacked on, company names are truncated at 21 characters.
      sheet = wb.create_sheet "#{company_name.to_s[0..20]} - REPORT"

      year_hash = condense_data_by_year_and_month data_arr

      # Four blank rows must be added to the top of the report to accomodate the logo image.
      for i in 0..3
        wb.add_body_row sheet, [] # blank row
      end
      wb.add_image sheet, "app/assets/images/vfi_track_logo.png", 198, 59, 0, 0

      counter = 6 # 4 blank rows at top plus 2 blanks in between the year blocks and the comparison block.
      counter += add_row_block wb, sheet, year_1, nil, 1, include_cotton_fee, include_taxes, include_other_fees, include_isf_fees, year_hash, group_by_mode_of_transport
      wb.add_body_row sheet, [] # blank row
      counter += add_row_block wb, sheet, year_2, nil, 2, include_cotton_fee, include_taxes, include_other_fees, include_isf_fees, year_hash, group_by_mode_of_transport
      wb.add_body_row sheet, [] # blank row
      # Compare the two years.
      counter += add_row_block wb, sheet, year_1, year_2, 3, include_cotton_fee, include_taxes, include_other_fees, include_isf_fees, year_hash, group_by_mode_of_transport

      wb.set_column_widths sheet, *([20] + Array.new(12, 14) + [15])

      if include_line_graphs
        add_charts sheet, counter, year_1, year_2, year_hash
      end

      sheet
    end

    def add_row_block wb, sheet, year, comp_year, block_pos, include_cotton_fee, include_taxes, include_other_fees, include_isf_fees, year_hash, group_by_mode_of_transport
      counter = 11
      wb.add_body_row sheet, make_summary_headers(comp_year ? "Variance #{year} / #{comp_year}" : year), styles: Array.new(14, :default_header)
      wb.add_body_row sheet, get_category_row_for_year_month("Number of Entries", year_hash, year, comp_year, block_pos, :entry_count, decimal:false), styles: [:bold] + Array.new(13, :number)
      wb.add_body_row sheet, get_category_row_for_year_month("Entry Summary Lines", year_hash, year, comp_year, block_pos, :entry_line_count, decimal:false), styles: [:bold] + Array.new(13, :number)
      wb.add_body_row sheet, get_category_row_for_year_month("Total Units", year_hash, year, comp_year, block_pos, :total_units), styles: [:bold] + Array.new(13, :number)
      get_all_entry_type_values(year_hash).each do |entry_type|
        wb.add_body_row sheet, get_category_row_for_year_month("Entry Type #{entry_type}", year_hash, year, comp_year, block_pos, :entry_type_count_hash, decimal:false, hash_key:entry_type), styles: [:bold] + Array.new(13, :number)
        counter += 1
      end
      if group_by_mode_of_transport
        get_all_mode_of_transportation_values(year_hash).each do |mot|
          wb.add_body_row sheet, get_category_row_for_year_month("Ship Mode #{mot}", year_hash, year, comp_year, block_pos, :mode_of_transportation_count_hash, decimal:false, hash_key:mot), styles: [:bold] + Array.new(13, :number)
          counter += 1
        end
      end
      wb.add_body_row sheet, get_category_row_for_year_month("Total Entered Value", year_hash, year, comp_year, block_pos, :entered_value), styles: [:bold] + Array.new(13, :currency)
      wb.add_body_row sheet, get_category_row_for_year_month("Total Duty", year_hash, year, comp_year, block_pos, :total_duty), styles: [:bold] + Array.new(13, :currency)
      wb.add_body_row sheet, get_category_row_for_year_month("MPF", year_hash, year, comp_year, block_pos, :mpf), styles: [:bold] + Array.new(13, :currency)
      wb.add_body_row sheet, get_category_row_for_year_month("HMF", year_hash, year, comp_year, block_pos, :hmf), styles: [:bold] + Array.new(13, :currency)
      if include_cotton_fee
        wb.add_body_row sheet, get_category_row_for_year_month("Cotton Fee", year_hash, year, comp_year, block_pos, :cotton_fee), styles: [:bold] + Array.new(13, :currency)
        counter += 1
      end
      if include_taxes
        wb.add_body_row sheet, get_category_row_for_year_month("Total Taxes", year_hash, year, comp_year, block_pos, :total_taxes), styles: [:bold] + Array.new(13, :currency)
        counter += 1
      end
      if include_other_fees
        wb.add_body_row sheet, get_category_row_for_year_month("Other Fees", year_hash, year, comp_year, block_pos, :other_fees), styles: [:bold] + Array.new(13, :currency)
        counter += 1
      end
      wb.add_body_row sheet, get_category_row_for_year_month("Total Fees", year_hash, year, comp_year, block_pos, :total_fees), styles: [:bold] + Array.new(13, :currency)
      wb.add_body_row sheet, get_category_row_for_year_month("Total Duty & Fees", year_hash, year, comp_year, block_pos, :total_duty_and_fees), styles: [:bold] + Array.new(13, :currency)
      wb.add_body_row sheet, get_category_row_for_year_month("Total Broker Invoice", year_hash, year, comp_year, block_pos, :broker_invoice_total), styles: [:bold] + Array.new(13, :currency)
      if include_isf_fees
        wb.add_body_row sheet, get_category_row_for_year_month("ISF Fees", year_hash, year, comp_year, block_pos, :isf_fees), styles: [:bold] + Array.new(13, :currency)
        counter += 1
      end
      counter
    end

    def get_all_entry_type_values year_hash
      get_all_year_hash_values year_hash, :entry_type_count_hash
    end

    # Note that these are descriptive categories, like Air or Sea, not the numeric codes used by customs.
    def get_all_mode_of_transportation_values year_hash
      mots = get_all_year_hash_values(year_hash, :mode_of_transportation_count_hash).to_a
      # Move the "N/A" category, if present, to the end of the array.
      if mots.include?("N/A")
        mots = (mots - ["N/A"]) + ["N/A"]
      end
      mots
    end

    def get_all_year_hash_values year_hash, count_hash_field
      ss = SortedSet.new
      year_hash.each_key do |key|
        month_hash = year_hash[key]
        for month in 1..12
          val_hash = month_hash[month].try(count_hash_field)
          if val_hash
            val_hash.each_key do |val|
              ss << val
            end
          end
        end
      end
      ss
    end

    def get_category_row_for_year_month category_name, year_hash, year, comp_year, block_pos, method_name, decimal:true, hash_key:nil, include_total_val:true
      row = []
      if category_name
        row << category_name
      end
      total_val = decimal ? 0.00 : 0
      for month in 1..12
        # Don't include values in columns for the current or future months if working with the current year,
        # avoiding showing negative variances as well.  The query limits data to the prior calendar month and earlier,
        # so this logic is essentially just here for cosmetic purposes.  For example, if it's May 2018, and we're
        # comparing 2017 and 2018 data, columns for May 2018 and beyond would be blank, as would the variance columns
        # beneath those.
        include_column_vals = true
        current_date = ActiveSupport::TimeZone[get_time_zone].now
        if block_pos > 1 && month >= current_date.month && current_date.year == (comp_year ? comp_year : year)
          include_column_vals = false
        end

        if include_column_vals
          val = get_year_month_hash_value year_hash, year, month, method_name, decimal, hash_key:hash_key
          if comp_year
            comp_val = get_year_month_hash_value year_hash, comp_year, month, method_name, decimal, hash_key:hash_key
            val = comp_val - val
          end
          total_val += val
          row << val
        else
          row << nil
        end
      end
      if include_total_val
        row << total_val
      end
      row
    end

    def get_year_month_hash_value year_hash, year, month, method_name, decimal, hash_key:nil
      val = year_hash[year].try(:[], month).try(method_name)
      if !hash_key.nil? && !val.nil?
        # If hash_key has a value, it means that val is actually a hash of counts by entry type or mode of
        # transportation.  The value we want to return is the count matching the specific key provided, which
        # could be nil.
        val = val[hash_key]
      end
      if val.nil?
        val = decimal ? 0.00 : 0
      end
      val
    end

    def condense_data_by_year_and_month data_arr
      year_hash = {}
      data_arr.each do |row|
        month_hash = year_hash[row.range_year]
        if month_hash.nil?
          month_hash = {}
          year_hash[row.range_year] = month_hash
        end

        month_data = month_hash[row.range_month]
        if month_data.nil?
          month_data = YearOverYearData.new
          month_hash[row.range_month] = month_data
          month_data.range_year = row.range_year
          month_data.range_month = row.range_month
        end

        month_data.entry_count += 1
        if month_data.entry_type_count_hash[row.entry_type].nil?
          month_data.entry_type_count_hash[row.entry_type] = 0
        end
        month_data.entry_type_count_hash[row.entry_type] += 1

        # Summarize data by mode of transportation.  Each human-readable mode (Air, Sea, Rail, Truck) includes multiple
        # numeric codes, the format the code is stored in within the database.  We don't have to care about
        # whether something is containerized or not for the purposes of this report.
        mode_of_transportation_code = translate_mode_of_transportation_code row.transport_mode_code
        if month_data.mode_of_transportation_count_hash[mode_of_transportation_code].nil?
          month_data.mode_of_transportation_count_hash[mode_of_transportation_code] = 0
        end
        month_data.mode_of_transportation_count_hash[mode_of_transportation_code] += 1

        month_data.entry_line_count += row.entry_line_count
        month_data.entered_value += row.entered_value
        month_data.total_duty += row.total_duty
        month_data.mpf += row.mpf
        month_data.hmf += row.hmf
        month_data.cotton_fee += row.cotton_fee
        month_data.total_taxes += row.total_taxes
        month_data.other_fees += row.other_fees
        month_data.total_fees += row.total_fees
        month_data.total_units += row.total_units
        month_data.total_gst += row.total_gst
        month_data.broker_invoice_total += row.broker_invoice_total
        month_data.isf_fees += row.isf_fees
      end

      year_hash
    end

    def translate_mode_of_transportation_code numeric_code
      ret_code = "N/A"
      ["Sea", "Air", "Truck", "Rail"].each do |text_code|
        if Entry.get_transport_mode_codes_us_ca(text_code).include?(numeric_code.to_i)
          ret_code = text_code
          break
        end
      end
      ret_code
    end

    def make_summary_headers first_col_val
      [first_col_val,"January","February","March","April","May","June","July","August","September","October","November","December","Grand Totals"]
    end

    # There is no need to condense the overall data on this tab.
    def generate_data_sheet wb, data_arr
      sheet = wb.create_sheet "Data", headers: ["Customer Number","Customer Name","Broker Reference","Entry Summary Line Count",
                                         "Entry Type","Total Entered Value","Total Duty","MPF","HMF","Cotton Fee",
                                         "Total Taxes","Total Fees","Other Taxes & Fees","Arrival Date","Release Date",
                                         "File Logged Date","Fiscal Date","ETA Date","Total Units","Total GST",
                                         "Country Export Codes","Mode of Transport","Total Broker Invoice","ISF Fees","Port of Entry Code"]

      data_arr.each do |row|
        wb.add_body_row sheet, [row.customer_number,row.customer_name,row.broker_reference,row.entry_line_count,row.entry_type,row.entered_value,row.total_duty,row.mpf,row.hmf,row.cotton_fee,row.total_taxes,row.other_fees,row.total_fees,row.arrival_date,row.release_date,row.file_logged_date,row.fiscal_date,row.eta_date,row.total_units,row.total_gst,row.export_country_codes,row.transport_mode_code,row.broker_invoice_total,row.isf_fees, row.entry_port_code], styles: Array.new(3, nil) + [:number, nil] + Array.new(8, :currency) + Array.new(5, nil) + [:number, :currency, nil, nil, :currency, nil]
      end

      wb.set_column_widths sheet, *Array.new(24, 20)

      sheet
    end

    # Note that this query excludes data from the current month and beyond, regardless of whether or not entries
    # may have matched the other date range parameters.  This replicates behavior of the manually-created report
    # this report replaces.
    def make_query importer_ids, year_1, year_2, range_field, mode_of_transport_codes, entry_types
      <<-SQL
      SELECT 
        YEAR(convert_tz(#{range_field}, "UTC", "#{get_time_zone}")) AS range_year_tz_converted, 
        MONTH(convert_tz(#{range_field}, "UTC", "#{get_time_zone}")) AS range_month_tz_converted, 
        YEAR(#{range_field}) AS range_year, 
        MONTH(#{range_field}) AS range_month, 
        customer_number, 
        customer_name, 
        broker_reference, 
        (
          SELECT 
            COUNT(*) 
          FROM 
            commercial_invoices AS ci 
            LEFT OUTER JOIN commercial_invoice_lines AS cil ON 
              ci.id = cil.commercial_invoice_id 
          WHERE 
            ci.entry_id = entries.id
        ) AS entry_line_count, 
        entry_type, 
        IFNULL(entered_value, 0.0) AS entered_value, 
        IFNULL(total_duty, 0.0) AS total_duty, 
        IFNULL(mpf, 0.0) AS mpf, 
        IFNULL(hmf, 0.0) AS hmf, 
        IFNULL(cotton_fee, 0.0) AS cotton_fee, 
        IFNULL(total_taxes, 0.0) AS total_taxes, 
        IFNULL(other_fees, 0.0) AS other_fees, 
        IFNULL(total_fees, 0.0) AS total_fees, 
        DATE(convert_tz(arrival_date, "UTC", "#{get_time_zone}")) AS arrival_date, 
        DATE(convert_tz(release_date, "UTC", "#{get_time_zone}")) AS release_date, 
        DATE(convert_tz(file_logged_date, "UTC", "#{get_time_zone}")) AS file_logged_date, 
        fiscal_date, 
        eta_date, 
        IFNULL(total_units, 0.0) AS total_units, 
        IFNULL(total_gst, 0.0) AS total_gst, 
        export_country_codes, 
        transport_mode_code, 
        IFNULL(broker_invoice_total, 0.0) AS broker_invoice_total, 
        (
          SELECT 
            IFNULL(SUM(charge_amount), 0.0) 
          FROM 
            broker_invoices AS bi 
            LEFT OUTER JOIN broker_invoice_lines AS bil ON 
              bi.id = bil.broker_invoice_id 
          WHERE 
            bi.entry_id = entries.id AND 
            bil.charge_code = '0191'
        ) AS isf_fees, 
        entry_port_code  
      FROM 
        entries 
      WHERE 
        importer_id IN (#{sanitize_string_in_list(importer_ids)}) AND 
        #{mode_of_transport_codes.length > 0 ? "transport_mode_code IN (" + sanitize_string_in_list(mode_of_transport_codes) + ") AND " : ""}
        #{entry_types && entry_types.length > 0 ? "entry_type IN (" + sanitize_string_in_list(entry_types) + ") AND " : ""}
        (
          (
            #{range_field} >= '#{format_jan_1_date(year_1, range_field)}' AND 
            #{range_field} < '#{format_jan_1_date(year_1 + 1, range_field)}'
          ) OR (
            #{range_field} >= '#{format_jan_1_date(year_2, range_field)}' AND 
            #{range_field} < '#{format_jan_1_date(year_2 + 1, range_field)}'
          )
        ) AND 
        #{range_field} < '#{format_first_day_of_current_month(range_field)}'
      ORDER BY
        #{range_field}
      SQL
    end

    def format_jan_1_date year, range_field
      if range_field_is_datetime range_field
        ActiveSupport::TimeZone[get_time_zone].parse("#{year}-01-01").to_s(:db)
      else
        Date.new(year, 1, 1)
      end
    end

    def format_first_day_of_current_month range_field
      format_first_day_of_month range_field, 0
    end

    def format_first_day_of_month range_field, month_adjustment
      if range_field_is_datetime range_field
        current_date = ActiveSupport::TimeZone[get_time_zone].now
        (ActiveSupport::TimeZone[get_time_zone].parse("#{current_date.year}-#{current_date.month}-01") + month_adjustment.month).to_s(:db)
      else
        (Date.new(Date.current.year, Date.current.month, 1) + month_adjustment.month)
      end
    end

    # Two of the five possible range fields are dates rather than datetime: Fiscal and ETA.
    # File Logged, Release and Arrival are all datetime.  Consequently, some date-related logic needs to be handled
    # differently, as datetimes are timezone-converted, and dates are not.
    def range_field_is_datetime range_field
      range_field != 'fiscal_date' && range_field != 'eta_date'
    end

    def get_time_zone
      "America/New_York"
    end

    def generate_port_breakdown_sheet wb, importer_ids, range_field, include_cotton_fee, include_taxes, include_other_fees, include_isf_fees, mode_of_transport_codes, included_entry_types
      result_set = ActiveRecord::Base.connection.exec_query make_port_breakdown_query(importer_ids, range_field, mode_of_transport_codes, included_entry_types)

      port_hash = {}
      result_set.each do |result_set_row|
        entry_port_name = result_set_row['entry_port_name']

        d = port_hash[entry_port_name]
        if d.nil?
          d = YearOverYearData.new
          d.entry_port_code = entry_port_name ? result_set_row['entry_port_code'] : "N/A"
          port_hash[entry_port_name] = d
        end

        entry_count = result_set_row['entry_count']
        d.entry_type_count_hash[result_set_row['entry_type']] = d.entry_type_count_hash[result_set_row['entry_type']].to_i + entry_count
        d.entry_count += entry_count
        d.entry_line_count += result_set_row['entry_line_count']
        d.entered_value += result_set_row['entered_value']
        d.total_duty += result_set_row['total_duty']
        d.mpf += result_set_row['mpf']
        d.hmf += result_set_row['hmf']
        d.cotton_fee += result_set_row['cotton_fee']
        d.total_taxes += result_set_row['total_taxes']
        d.other_fees += result_set_row['other_fees']
        d.total_fees += result_set_row['total_fees']
        d.total_units += result_set_row['total_units']
        d.broker_invoice_total += result_set_row['broker_invoice_total']
        d.isf_fees += result_set_row['isf_fees']
      end

      entry_types = SortedSet.new
      port_hash.each_key do |entry_port_name|
        entry_types.merge port_hash[entry_port_name].entry_type_count_hash.keys
      end

      column_headings = make_port_breakdown_column_headings entry_types, include_cotton_fee, include_taxes, include_other_fees, include_isf_fees
      sheet = wb.create_sheet "Port Breakdown", headers: column_headings

      # Row for every port.
      port_hash.each_key do |entry_port_name|
        next unless entry_port_name

        d = port_hash[entry_port_name]
        row = make_port_breakdown_row d, entry_port_name, entry_types, include_cotton_fee, include_taxes, include_other_fees, include_isf_fees
        wb.add_body_row sheet, row, styles: get_port_breakdown_row_formats(entry_types, column_headings)
      end

      # Single 'N/A' row for any entries that don't have an entry port assigned, or a bogus entry port.
      d = port_hash[nil]
      if d
        row = make_port_breakdown_row d, 'N/A', entry_types, include_cotton_fee, include_taxes, include_other_fees, include_isf_fees
        wb.add_body_row sheet, row, styles: get_port_breakdown_row_formats(entry_types, column_headings)
      end

      # Totals row.
      totals = YearOverYearData.new
      port_hash.each_key do |entry_port_name|
        port_data = port_hash[entry_port_name]
        totals.entry_count += port_data.entry_count
        totals.entry_line_count += port_data.entry_line_count
        totals.entered_value += port_data.entered_value
        totals.total_duty += port_data.total_duty
        totals.mpf += port_data.mpf
        totals.hmf += port_data.hmf
        totals.cotton_fee += port_data.cotton_fee
        totals.total_taxes += port_data.total_taxes
        totals.other_fees += port_data.other_fees
        totals.total_fees += port_data.total_fees
        totals.total_units += port_data.total_units
        totals.broker_invoice_total += port_data.broker_invoice_total
        totals.isf_fees += port_data.isf_fees

        entry_types.each do |entry_type|
          if totals.entry_type_count_hash[entry_type].nil?
            totals.entry_type_count_hash[entry_type] = 0
          end
          totals.entry_type_count_hash[entry_type] += (port_data.entry_type_count_hash[entry_type].presence || 0)
        end
      end
      totals_row = make_port_breakdown_row totals, 'Grand Totals', entry_types, include_cotton_fee, include_taxes, include_other_fees, include_isf_fees
      wb.add_body_row sheet, totals_row, styles: get_port_breakdown_row_formats(entry_types, column_headings)

      wb.set_column_widths sheet, *([30] + Array.new(column_headings.length - 1, 20))

      sheet
    end

    def make_port_breakdown_column_headings entry_types, include_cotton_fee, include_taxes, include_other_fees, include_isf_fees
      column_headings = ["#{Date.today.strftime("%B %Y")} Port Breakdown","Entry Port Code","Number of Entries","Entry Summary Lines","Total Units"]

      entry_types.each do |entry_type|
        next unless entry_type
        column_headings << "Entry Type #{entry_type}"
      end

      column_headings += ["Total Entered Value","Total Duty","MPF","HMF"]
      if include_cotton_fee
        column_headings << "Cotton Fee"
      end
      if include_taxes
        column_headings << "Total Taxes"
      end
      if include_other_fees
        column_headings << "Other Taxes & Fees"
      end
      column_headings += ["Total Fees","Total Broker Invoice"]
      if include_isf_fees
        column_headings << "ISF Fees"
      end
      column_headings
    end

    def make_port_breakdown_row d, entry_port_name, entry_types, include_cotton_fee, include_taxes, include_other_fees, include_isf_fees
      row_arr = [entry_port_name, d.entry_port_code, d.entry_count, d.entry_line_count, d.total_units]
      entry_types.each do |entry_type|
        entry_type_count = d.entry_type_count_hash[entry_type]
        row_arr << (entry_type_count.presence || 0)
      end
      row_arr += [d.entered_value, d.total_duty, d.mpf, d.hmf]
      if include_cotton_fee
        row_arr << d.cotton_fee
      end
      if include_taxes
        row_arr << d.total_taxes
      end
      if include_other_fees
        row_arr << d.other_fees
      end
      row_arr += [d.total_fees, d.broker_invoice_total]
      if include_isf_fees
        row_arr << d.isf_fees
      end
      row_arr
    end

    def get_port_breakdown_row_formats entry_types, column_headings
      [nil] + Array.new(4 + entry_types.length, :number) + Array.new(column_headings.length - 5 - entry_types.length, :currency)
    end

    # Params applied to this query are the same as the "main" query.  This tab runs over the current reporting month,
    # however, which is the previous month: different date range than the other tabs, but date is still calculated
    # from the same date field as the other query.
    def make_port_breakdown_query importer_ids, range_field, mode_of_transport_codes, entry_types
      <<-SQL
        SELECT 
          entry_port_name, 
          entry_port_code, 
          entry_type, 
          COUNT(*) AS entry_count, 
          SUM(entry_line_count) AS entry_line_count, 
          SUM(total_units) AS total_units, 
          SUM(entered_value) AS entered_value, 
          SUM(total_duty) AS total_duty, 
          SUM(mpf) AS mpf, 
          SUM(hmf) AS hmf, 
          SUM(cotton_fee) AS cotton_fee, 
          SUM(total_taxes) AS total_taxes, 
          SUM(other_fees) AS other_fees, 
          SUM(total_fees) AS total_fees, 
          SUM(broker_invoice_total) AS broker_invoice_total, 
          SUM(isf_fees) AS isf_fees 
        FROM 
          (
            SELECT 
              entry_port.name AS entry_port_name, 
              entry_port_code, 
              entry_type, 
              (
                SELECT 
                  COUNT(*) 
                FROM 
                  commercial_invoices AS ci 
                  LEFT OUTER JOIN commercial_invoice_lines AS cil ON 
                    ci.id = cil.commercial_invoice_id 
                WHERE 
                  ci.entry_id = entries.id
              ) AS entry_line_count, 
              IFNULL(total_units, 0.0) AS total_units, 
              IFNULL(entered_value, 0.0) AS entered_value, 
              IFNULL(total_duty, 0.0) AS total_duty, 
              IFNULL(mpf, 0.0) AS mpf, 
              IFNULL(hmf, 0.0) AS hmf, 
              IFNULL(cotton_fee, 0.0) AS cotton_fee, 
              IFNULL(total_taxes, 0.0) AS total_taxes, 
              IFNULL(other_fees, 0.0) AS other_fees, 
              IFNULL(total_fees, 0.0) AS total_fees, 
              IFNULL(broker_invoice_total, 0.0) AS broker_invoice_total, 
              (
                SELECT 
                  IFNULL(SUM(charge_amount), 0.0) 
                FROM 
                  broker_invoices AS bi 
                  LEFT OUTER JOIN broker_invoice_lines AS bil ON 
                    bi.id = bil.broker_invoice_id 
                WHERE 
                  bi.entry_id = entries.id AND 
                  bil.charge_code = '0191'
              ) AS isf_fees 
            FROM 
              entries 
              LEFT OUTER JOIN ports AS entry_port ON 
                (
                 (entries.entry_port_code = entry_port.schedule_d_code AND entries.import_country_id = #{Country.where(iso_code:'US').first.try(:id).to_i})
                 OR 
                 (entries.entry_port_code = entry_port.cbsa_port AND entries.import_country_id = #{Country.where(iso_code:'CA').first.try(:id).to_i})
                )
            WHERE 
              importer_id IN (#{sanitize_string_in_list(importer_ids)}) AND 
              #{mode_of_transport_codes.length > 0 ? "transport_mode_code IN (" + sanitize_string_in_list(mode_of_transport_codes) + ") AND " : ""}
              #{entry_types && entry_types.length > 0 ? "entry_type IN (" + sanitize_string_in_list(entry_types) + ") AND " : ""}
              #{range_field} >= '#{format_first_day_of_month(range_field, -1)}' AND 
              #{range_field} < '#{format_first_day_of_current_month(range_field)}'
          ) AS tbl 
        GROUP BY 
          entry_port_name, 
          entry_port_code, 
          entry_type 
        ORDER BY
          entry_port_name, 
          entry_type
      SQL
    end

    def add_charts sheet, counter, year_1, year_2, year_hash
      chart_builder = XlsxChartBuilder.new
      month_headings = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

      chart_builder.create_line_chart sheet, "Entries Transmitted", "A#{counter + 2}", "F#{counter + 17}", x_axis_labels:month_headings do |chart|
        chart.add_data get_category_row_for_year_month(nil, year_hash, year_1, nil, 1, :entry_count, decimal:false, include_total_val:false), year_1.to_s, "0000FF"
        chart.add_data get_category_row_for_year_month(nil, year_hash, year_2, nil, 2, :entry_count, decimal:false, include_total_val:false), year_2.to_s, "FF0000"
      end

      chart_builder.create_line_chart sheet, "Line Item Count", "G#{counter + 2}", "L#{counter + 17}", x_axis_labels:month_headings do |chart|
        chart.add_data get_category_row_for_year_month(nil, year_hash, year_1, nil, 1, :entry_line_count, decimal:false, include_total_val:false), year_1.to_s, "0000FF"
        chart.add_data get_category_row_for_year_month(nil, year_hash, year_2, nil, 2, :entry_line_count, decimal:false, include_total_val:false), year_2.to_s, "FF0000"
      end

      chart_builder.create_line_chart sheet, "Total Broker Invoice", "M#{counter + 2}", "S#{counter + 17}", x_axis_labels:month_headings do |chart|
        chart.add_data get_category_row_for_year_month(nil, year_hash, year_1, nil, 1, :broker_invoice_total, decimal:false, include_total_val:false), year_1.to_s, "0000FF"
        chart.add_data get_category_row_for_year_month(nil, year_hash, year_2, nil, 2, :broker_invoice_total, decimal:false, include_total_val:false), year_2.to_s, "FF0000"
      end
    end

end; end; end