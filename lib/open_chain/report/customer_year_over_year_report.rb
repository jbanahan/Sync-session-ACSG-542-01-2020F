require 'open_chain/report/report_helper'

module OpenChain; module Report; class CustomerYearOverYearReport
  include OpenChain::Report::ReportHelper

  ENTRY_YEAR_OVER_YEAR_REPORT_USERS ||= 'entry_yoy_report'

  BOLD_FORMAT ||= XlsMaker.create_format "Bolded", weight: :bold
  BLUE_HEADER_FORMAT ||= XlsMaker.create_format "Blue Header", weight: :bold, horizontal_align: :merge, pattern_fg_color: :xls_color_41, pattern: 1
  MONEY_FORMAT ||= XlsMaker.create_format "Money", :number_format => '$#,##0.00'
  NUMBER_FORMAT ||= XlsMaker.create_format "Number", :number_format => '#,##0', horizontal_align: :center

  YearOverYearData ||= Struct.new(:range_year,:range_month,:customer_number,:customer_name,:broker_reference,
                                       :entry_line_count,:entry_type,:entered_value,:total_duty,:mpf,:hmf,:cotton_fee,
                                       :total_taxes,:other_fees,:total_fees,:arrival_date,:release_date,
                                       :file_logged_date,:fiscal_date,:eta_date,:total_units,:total_gst,
                                       :export_country_codes,:transport_mode_code,:broker_invoice_total,
                                       :entry_type_count_hash,:entry_count) do
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

  def run_year_over_year_report settings
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

    mode_of_transport_codes = get_transport_mode_codes settings['mode_of_transport']

    importer_ids = settings['importer_ids']
    range_field = settings['range_field']
    workbook = generate_report importer_ids, year_1, year_2, range_field, settings['include_cotton_fee'], settings['include_taxes'], settings['include_other_fees'], mode_of_transport_codes

    system_code = importer_ids.length == 1 ? Company.find(importer_ids[0]).try(:system_code).to_s : 'MULTI'
    file_name = "Entry_YoY_#{system_code}_#{range_field}_[#{year_1}_#{year_2}].xls"
    workbook_to_tempfile(workbook, "YoY Report", file_name: "#{file_name}")
  end

  private
    def get_transport_mode_codes modes_param
      mode_of_transport_codes = []
      modes_param.try(:each) {|mode| Entry.get_transport_mode_codes_us_ca(mode).each {|i| mode_of_transport_codes << i }}
      mode_of_transport_codes
    end

    def generate_report importer_ids, year_1, year_2, range_field, include_cotton_fee, include_taxes, include_other_fees, mode_of_transport_codes
      wb = XlsMaker.new_workbook

      raw_data = []
      result_set = ActiveRecord::Base.connection.exec_query make_query(importer_ids, year_1, year_2, range_field, mode_of_transport_codes)
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
        raw_data << d
      end

      generate_summary_sheet wb, importer_ids, year_1, year_2, include_cotton_fee, include_taxes, include_other_fees, raw_data
      generate_data_sheet wb, raw_data

      wb
    end

    # This sheet contains data summarized by month and year.
    def generate_summary_sheet wb, importer_ids, year_1, year_2, include_cotton_fee, include_taxes, include_other_fees, data_arr
      company_name = importer_ids.length == 1 ? Company.find(importer_ids[0]).try(:name) : "MULTI COMPANY"
      # Handling long company names: some versions of Excel allow only 30 characters for tab names, so, because of the
      # 9-char suffix tacked on, company names are truncated at 21 characters.
      sheet = XlsMaker.create_sheet wb, "#{company_name.to_s[0..20]} - REPORT", []

      year_hash = condense_data_by_year_and_month data_arr

      counter = -1
      counter = add_row_block sheet, year_1, nil, 1, counter, include_cotton_fee, include_taxes, include_other_fees, year_hash
      counter += 1 # blank row
      counter = add_row_block sheet, year_2, nil, 2, counter, include_cotton_fee, include_taxes, include_other_fees, year_hash
      counter += 1 # blank row
      # Compare the two years.
      counter = add_row_block sheet, year_1, year_2, 3, counter, include_cotton_fee, include_taxes, include_other_fees, year_hash

      XlsMaker.set_column_widths sheet, ([20] + Array.new(12, 14) + [15])

      sheet
    end

    def add_row_block sheet, year, comp_year, block_pos, counter, include_cotton_fee, include_taxes, include_other_fees, year_hash
      XlsMaker.add_body_row sheet, counter += 1, make_summary_headers(comp_year ? "Variance #{year} / #{comp_year}" : year), [], false, formats: Array.new(14, BLUE_HEADER_FORMAT)
      XlsMaker.add_body_row sheet, counter += 1, get_category_row_for_year_month("Number of Entries", year_hash, year, comp_year, block_pos, :entry_count, decimal:false), [], false, formats: [BOLD_FORMAT] + Array.new(13, NUMBER_FORMAT)
      XlsMaker.add_body_row sheet, counter += 1, get_category_row_for_year_month("Entry Summary Lines", year_hash, year, comp_year, block_pos, :entry_line_count, decimal:false), [], false, formats: [BOLD_FORMAT] + Array.new(13, NUMBER_FORMAT)
      XlsMaker.add_body_row sheet, counter += 1, get_category_row_for_year_month("Total Units", year_hash, year, comp_year, block_pos, :total_units), [], false, formats: [BOLD_FORMAT] + Array.new(13, NUMBER_FORMAT)
      get_all_entry_type_values(year_hash).each do |entry_type|
        XlsMaker.add_body_row sheet, counter += 1, get_category_row_for_year_month("Entry Type #{entry_type}", year_hash, year, comp_year, block_pos, :entry_type_count_hash, decimal:false, entry_type:entry_type), [], false, formats: [BOLD_FORMAT] + Array.new(13, NUMBER_FORMAT)
      end
      XlsMaker.add_body_row sheet, counter += 1, get_category_row_for_year_month("Total Entered Value", year_hash, year, comp_year, block_pos, :entered_value), [], false, formats: [BOLD_FORMAT] + Array.new(13, MONEY_FORMAT)
      XlsMaker.add_body_row sheet, counter += 1, get_category_row_for_year_month("Total Duty", year_hash, year, comp_year, block_pos, :total_duty), [], false, formats: [BOLD_FORMAT] + Array.new(13, MONEY_FORMAT)
      XlsMaker.add_body_row sheet, counter += 1, get_category_row_for_year_month("MPF", year_hash, year, comp_year, block_pos, :mpf), [], false, formats: [BOLD_FORMAT] + Array.new(13, MONEY_FORMAT)
      XlsMaker.add_body_row sheet, counter += 1, get_category_row_for_year_month("HMF", year_hash, year, comp_year, block_pos, :hmf), [], false, formats: [BOLD_FORMAT] + Array.new(13, MONEY_FORMAT)
      if include_cotton_fee
        XlsMaker.add_body_row sheet, counter += 1, get_category_row_for_year_month("Cotton Fee", year_hash, year, comp_year, block_pos, :cotton_fee), [], false, formats: [BOLD_FORMAT] + Array.new(13, MONEY_FORMAT)
      end
      if include_taxes
        XlsMaker.add_body_row sheet, counter += 1, get_category_row_for_year_month("Total Taxes", year_hash, year, comp_year, block_pos, :total_taxes), [], false, formats: [BOLD_FORMAT] + Array.new(13, MONEY_FORMAT)
      end
      if include_other_fees
        XlsMaker.add_body_row sheet, counter += 1, get_category_row_for_year_month("Other Fees", year_hash, year, comp_year, block_pos, :other_fees), [], false, formats: [BOLD_FORMAT] + Array.new(13, MONEY_FORMAT)
      end
      XlsMaker.add_body_row sheet, counter += 1, get_category_row_for_year_month("Total Fees", year_hash, year, comp_year, block_pos, :total_fees), [], false, formats: [BOLD_FORMAT] + Array.new(13, MONEY_FORMAT)
      XlsMaker.add_body_row sheet, counter += 1, get_category_row_for_year_month("Total Duty & Fees", year_hash, year, comp_year, block_pos, :total_duty_and_fees), [], false, formats: [BOLD_FORMAT] + Array.new(13, MONEY_FORMAT)
      XlsMaker.add_body_row sheet, counter += 1, get_category_row_for_year_month("Total Broker Invoice", year_hash, year, comp_year, block_pos, :broker_invoice_total), [], false, formats: [BOLD_FORMAT] + Array.new(13, MONEY_FORMAT)
      counter
    end

    def get_all_entry_type_values year_hash
      ss = SortedSet.new
      year_hash.each_key do |key|
        month_hash = year_hash[key]
        for month in 1..12
          type_hash = month_hash[month].try(:entry_type_count_hash)
          if type_hash
            type_hash.each_key do |entry_type|
              ss << entry_type
            end
          end
        end
      end
      ss
    end

    def get_category_row_for_year_month category_name, year_hash, year, comp_year, block_pos, method_name, decimal:true, entry_type:nil
      row = [category_name]
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
          val = get_year_month_hash_value year_hash, year, month, method_name, decimal, entry_type:entry_type
          if comp_year
            comp_val = get_year_month_hash_value year_hash, comp_year, month, method_name, decimal, entry_type:entry_type
            val = comp_val - val
          end
          total_val += val
          row << val
        else
          row << nil
        end
      end
      row << total_val
      row
    end

    def get_year_month_hash_value year_hash, year, month, method_name, decimal, entry_type:nil
      val = year_hash[year].try(:[], month).try(method_name)
      if !entry_type.nil? && !val.nil?
        # If entry_type has a value, it means that val is actually a hash of counts by entry type.
        # The value we want to return is the count matching the specific entry type provided,
        # which could be nil.
        val = val[entry_type]
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
          month_data.entry_count = 0
          month_data.entry_line_count = 0
          month_data.entered_value = 0.00
          month_data.total_duty = 0.00
          month_data.mpf = 0.00
          month_data.hmf = 0.00
          month_data.cotton_fee = 0.00
          month_data.total_taxes = 0.00
          month_data.other_fees = 0.00
          month_data.total_fees = 0.00
          month_data.total_units = 0.00
          month_data.total_gst = 0.00
          month_data.broker_invoice_total = 0.00
          month_data.entry_type_count_hash = {}
        end

        month_data.entry_count += 1
        if month_data.entry_type_count_hash[row.entry_type].nil?
          month_data.entry_type_count_hash[row.entry_type] = 0
        end
        month_data.entry_type_count_hash[row.entry_type] += 1
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
      end

      year_hash
    end

    def make_summary_headers first_col_val
      [first_col_val,"January","February","March","April","May","June","July","August","September","October","November","December","Grand Totals"]
    end

    # There is no need to condense the overall data on this tab.
    def generate_data_sheet wb, data_arr
      sheet = XlsMaker.create_sheet wb, "Data", ["Customer Number","Customer Name","Broker Reference","Entry Summary Line Count",
                                         "Entry Type","Total Entered Value","Total Duty","MPF","HMF","Cotton Fee",
                                         "Total Taxes","Total Fees","Other Taxes & Fees","Arrival Date","Release Date",
                                         "File Logged Date","Fiscal Date","ETA Date","Total Units","Total GST",
                                         "Country Export Codes","Mode of Transport","Total Broker Invoice"]

      counter = 0
      data_arr.each do |row|
        XlsMaker.add_body_row sheet, counter += 1, [row.customer_number,row.customer_name,row.broker_reference,row.entry_line_count,row.entry_type,row.entered_value,row.total_duty,row.mpf,row.hmf,row.cotton_fee,row.total_taxes,row.other_fees,row.total_fees,row.arrival_date,row.release_date,row.file_logged_date,row.fiscal_date,row.eta_date,row.total_units,row.total_gst,row.export_country_codes,row.transport_mode_code,row.broker_invoice_total], [], false, formats: Array.new(3, nil) + [NUMBER_FORMAT, nil] + Array.new(8, MONEY_FORMAT) + Array.new(5, nil) + [NUMBER_FORMAT, MONEY_FORMAT, nil, nil, MONEY_FORMAT]
      end

      XlsMaker.set_column_widths sheet, Array.new(23, 20)

      sheet
    end

    # Note that this query excludes data from the current month and beyond, regardless of whether or not entries
    # may have matched the other date range parameters.  This replicates behavior of the manually-created report
    # this report replaces.
    def make_query importer_ids, year_1, year_2, range_field, mode_of_transport_codes
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
        IFNULL(broker_invoice_total, 0.0) AS broker_invoice_total 
      FROM 
        entries 
      WHERE 
        importer_id IN (#{importer_ids.join(',')}) AND 
        #{mode_of_transport_codes.length > 0 ? "transport_mode_code IN (" + mode_of_transport_codes.join(',') + ") AND " : ""}
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
      if range_field_is_datetime range_field
        current_date = ActiveSupport::TimeZone[get_time_zone].now
        ActiveSupport::TimeZone[get_time_zone].parse("#{current_date.year}-#{current_date.month}-01").to_s(:db)
      else
        Date.new(Date.current.year, Date.current.month, 1)
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

end; end; end