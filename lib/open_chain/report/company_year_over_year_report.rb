require 'open_chain/report/report_helper'

module OpenChain; module Report; class CompanyYearOverYearReport
  include OpenChain::Report::ReportHelper

  COMPANY_YEAR_OVER_YEAR_REPORT_USERS ||= 'company_yoy_report'

  CompanyYearOverYearData ||= Struct.new(:entry_count, :entry_invoice_count, :entry_line_count, :abi_line_count, :total_broker_invoice)

  def self.permission? user
    user.view_entries? && MasterSetup.get.custom_feature?("Company Year Over Year Report") && user.in_group?(Group.use_system_group(COMPANY_YEAR_OVER_YEAR_REPORT_USERS, create: false))
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

    workbook = nil
    distribute_reads do
      workbook = generate_report year_1, year_2
    end

    file_name = "Company_YoY_[#{year_1}_#{year_2}].xlsx"
    if settings['email'].present?
      workbook_to_tempfile workbook, "YoY Report", file_name: "#{file_name}" do |temp|
        OpenMailer.send_simple_html(settings['email'], "Company YoY Report #{year_1} vs. #{year_2}", "The VFI year-over-year report is attached, comparing #{year_1} and #{year_2}.", temp).deliver_now
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

    def generate_report year_1, year_2
      wb = XlsxBuilder.new
      assign_styles wb

      result_set = ActiveRecord::Base.connection.exec_query make_query(year_1, year_2)
      division_hash = {}
      result_set.each do |result_set_row|
        division = "#{result_set_row['division_number']} - #{result_set_row['division_name']}"
        year_hash = division_hash[division]
        if year_hash.nil?
          year_hash = {}
          division_hash[division] = year_hash
        end

        range_year = result_set_row['range_year']
        month_hash = year_hash[range_year]
        if month_hash.nil?
          month_hash = {}
          year_hash[range_year] = month_hash
        end

        range_month = result_set_row['range_month']
        month_data = month_hash[range_month]
        if month_data.nil?
          month_data = CompanyYearOverYearData.new
          month_data.entry_count = result_set_row['entry_count']
          month_data.entry_invoice_count = result_set_row['entry_invoice_count']
          month_data.entry_line_count = result_set_row['entry_line_count']
          month_data.abi_line_count = result_set_row['abi_line_count']
          month_data.total_broker_invoice = result_set_row['broker_invoice_total']
          month_hash[range_month] = month_data
        end
      end

      division_hash.each_key do |division|
        sheet = wb.create_sheet "#{division}"
        year_hash = division_hash[division]

        # YTD-limiting of totals is enforced if we're working with the current year.
        ytd_enforced = year_2 == ActiveSupport::TimeZone[get_time_zone].now.year

        add_row_block wb, sheet, year_1, nil, 1, year_hash, ytd_enforced
        wb.add_body_row sheet, [] # blank row
        add_row_block wb, sheet, year_2, nil, 2, year_hash, ytd_enforced
        wb.add_body_row sheet, [] # blank row
        # Compare the two years.
        add_row_block wb, sheet, year_1, year_2, 3, year_hash, ytd_enforced

        wb.set_column_widths sheet, *([20] + Array.new(12, 14) + [17])
      end

      wb
    end

    def assign_styles wb
      wb.create_style :bold, {b: true}
      wb.create_style(:currency, {format_code: "$#,##0.00"})
      wb.create_style(:number, {format_code: "#,##0"})
    end

    def add_row_block wb, sheet, year, comp_year, block_pos, year_hash, ytd_enforced
      wb.add_body_row sheet, make_data_headers(comp_year ? "Variance" : year), styles: Array.new(14, :default_header)
      wb.add_body_row sheet, get_category_row_for_year_month("Entries Transmitted", year_hash, year, comp_year, block_pos, ytd_enforced, :entry_count, decimal:false), styles: [:bold] + Array.new(13, :number)
      wb.add_body_row sheet, get_category_row_for_year_month("Entry Summary Invoices", year_hash, year, comp_year, block_pos, ytd_enforced, :entry_invoice_count, decimal:false), styles: [:bold] + Array.new(13, :number)
      wb.add_body_row sheet, get_category_row_for_year_month("Entry Summary Lines", year_hash, year, comp_year, block_pos, ytd_enforced, :entry_line_count, decimal:false), styles: [:bold] + Array.new(13, :number)
      wb.add_body_row sheet, get_category_row_for_year_month("ABI Lines", year_hash, year, comp_year, block_pos, ytd_enforced, :abi_line_count, decimal:false), styles: [:bold] + Array.new(13, :number)
      wb.add_body_row sheet, get_category_row_for_year_month("Total Broker Invoice", year_hash, year, comp_year, block_pos, ytd_enforced, :total_broker_invoice), styles: [:bold] + Array.new(13, :currency)
      nil
    end

    def get_category_row_for_year_month category_name, year_hash, year, comp_year, block_pos, ytd_enforced, method_name, decimal:true
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

        # The total value column is "YTD", so if we're working on a set of years that involves the current year, it
        # should exclude counts/amounts for months of the previous year belonging to months prior to the current month.
        # Presumably, this is so apples-to-apples totals comparisons can be made between the two years.
        # For example, if it's May 2018, and we're comparing 2017 and 2018 data, the 2017 entry count YTD total would
        # include the summed counts of the January to April columns only, ignoring all entries received from May to
        # December 2017.
        include_in_ytd_totals = true
        if ytd_enforced && month >= current_date.month
          include_in_ytd_totals = false
        end

        if include_column_vals
          val = get_year_month_hash_value year_hash, year, month, method_name, decimal
          if comp_year
            comp_val = get_year_month_hash_value year_hash, comp_year, month, method_name, decimal
            val = comp_val - val
          end
          if include_in_ytd_totals
            total_val += val
          end
          row << val
        else
          row << nil
        end
      end
      row << total_val
      row
    end

    def get_year_month_hash_value year_hash, year, month, method_name, decimal
      val = year_hash[year].try(:[], month).try(method_name)
      if val.nil?
        val = decimal ? 0.00 : 0
      end
      val
    end

    def make_data_headers first_col_val
      [first_col_val, "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec", "Grand Total (YTD)"]
    end

    # Note that this query excludes data from the current month and beyond, regardless of whether or not entries
    # may have matched the other date range parameters.  This replicates behavior of the manually-created report
    # this report replaces.
    def make_query year_1, year_2
      <<-SQL
        SELECT
          range_year,
          range_month,
          division_number,
          division_name,
          SUM(entry_count) AS entry_count,
          SUM(entry_invoice_count) AS entry_invoice_count,
          SUM(entry_line_count) AS entry_line_count,
          SUM(abi_line_count) AS abi_line_count,
          SUM(broker_invoice_total) AS broker_invoice_total
        FROM
          (
            (
              SELECT
                YEAR(convert_tz(release_date, "UTC", "#{get_time_zone}")) AS range_year,
                MONTH(convert_tz(release_date, "UTC", "#{get_time_zone}")) AS range_month,
                division_number,
                div_xref.value AS division_name,
                COUNT(*) AS entry_count,
                SUM(IFNULL(child_count_tbl.entry_invoice_count, 0)) AS entry_invoice_count,
                SUM(IFNULL(child_count_tbl.entry_line_count, 0)) AS entry_line_count,
                SUM(IFNULL(summary_line_count, 0)) AS abi_line_count,
                SUM(IFNULL(broker_invoice_total, 0.0)) AS broker_invoice_total
              FROM
                entries
                LEFT OUTER JOIN data_cross_references AS div_xref ON
                  div_xref.cross_reference_type = '#{DataCrossReference::VFI_DIVISION}' AND
                  div_xref.key = entries.division_number
                LEFT OUTER JOIN (
                  SELECT
                    entries.id AS entry_id,
                    COUNT(DISTINCT ci.id) AS entry_invoice_count,
                    COUNT(cil.id) AS entry_line_count
                  FROM
                    entries
                    LEFT OUTER JOIN commercial_invoices AS ci ON
                      entries.id = ci.entry_id
                    LEFT OUTER JOIN commercial_invoice_lines AS cil ON
                      ci.id = cil.commercial_invoice_id
                  WHERE
                    division_number IS NOT NULL AND
                    !(customer_number <=> 'EDDIEFTZ') AND
                    #{make_range_field_sql('release_date', year_1, year_2)}
                  GROUP BY
                    entries.id
                ) AS child_count_tbl ON
	                entries.id = child_count_tbl.entry_id
              WHERE
                division_number IS NOT NULL AND
                !(customer_number <=> 'EDDIEFTZ') AND
                #{make_range_field_sql('release_date', year_1, year_2)}
              GROUP BY
                division_number,
                div_xref.value,
                YEAR(convert_tz(release_date, "UTC", "#{get_time_zone}")),
                MONTH(convert_tz(release_date, "UTC", "#{get_time_zone}"))
            ) UNION (
              SELECT
                YEAR(convert_tz(arrival_date, "UTC", "#{get_time_zone}")) AS range_year,
                MONTH(convert_tz(arrival_date, "UTC", "#{get_time_zone}")) AS range_month,
                division_number,
                div_xref.value AS division_name,
                COUNT(*) AS entry_count,
                SUM(IFNULL(child_count_tbl.entry_invoice_count, 0)) AS entry_invoice_count,
                SUM(IFNULL(child_count_tbl.entry_line_count, 0)) AS entry_line_count,
                SUM(IFNULL(summary_line_count, 0)) AS abi_line_count,
                SUM(IFNULL(broker_invoice_total, 0.0)) AS broker_invoice_total
              FROM
                entries
                LEFT OUTER JOIN data_cross_references AS div_xref ON
                  div_xref.cross_reference_type = '#{DataCrossReference::VFI_DIVISION}' AND
                  div_xref.key = entries.division_number
                LEFT OUTER JOIN (
                  SELECT
                    entries.id AS entry_id,
                    COUNT(DISTINCT ci.id) AS entry_invoice_count,
                    COUNT(cil.id) AS entry_line_count
                  FROM
                    entries
                    LEFT OUTER JOIN commercial_invoices AS ci ON
                      entries.id = ci.entry_id
                    LEFT OUTER JOIN commercial_invoice_lines AS cil ON
                      ci.id = cil.commercial_invoice_id
                  WHERE
                    division_number IS NOT NULL AND
                    customer_number = 'EDDIEFTZ' AND
                    #{make_range_field_sql('arrival_date', year_1, year_2)}
                  GROUP BY
                    entries.id
                ) AS child_count_tbl ON
	                entries.id = child_count_tbl.entry_id
              WHERE
                division_number IS NOT NULL AND
                customer_number = 'EDDIEFTZ' AND
                #{make_range_field_sql('arrival_date', year_1, year_2)}
              GROUP BY
                division_number,
                div_xref.value,
                YEAR(convert_tz(arrival_date, "UTC", "#{get_time_zone}")),
                MONTH(convert_tz(arrival_date, "UTC", "#{get_time_zone}"))
            ) UNION (
              SELECT
                YEAR(convert_tz(release_date, "UTC", "#{get_time_zone}")) AS range_year,
                MONTH(convert_tz(release_date, "UTC", "#{get_time_zone}")) AS range_month,
                'CA' AS division_number,
                'Toronto' AS division_name,
                COUNT(*) AS entry_count,
                SUM(IFNULL(child_count_tbl.entry_invoice_count, 0)) AS entry_invoice_count,
                SUM(IFNULL(child_count_tbl.entry_line_count, 0)) AS entry_line_count,
                SUM(IFNULL(summary_line_count, 0)) AS abi_line_count,
                SUM(IFNULL(broker_invoice_total, 0.0)) AS broker_invoice_total
              FROM
                entries
                LEFT OUTER JOIN (
                  SELECT
                    entries.id AS entry_id,
                    COUNT(DISTINCT ci.id) AS entry_invoice_count,
                    COUNT(cil.id) AS entry_line_count
                  FROM
                    entries
                    LEFT OUTER JOIN commercial_invoices AS ci ON
                      entries.id = ci.entry_id
                    LEFT OUTER JOIN commercial_invoice_lines AS cil ON
                      ci.id = cil.commercial_invoice_id
                  WHERE
                    division_number IS NULL AND
                    !(customer_number <=> 'EDDIEFTZ') AND
                    #{make_range_field_sql('release_date', year_1, year_2)}
                  GROUP BY
                    entries.id
                ) AS child_count_tbl ON
	                entries.id = child_count_tbl.entry_id
              WHERE
                division_number IS NULL AND
                entry_number LIKE '1198%' AND
                #{make_range_field_sql('release_date', year_1, year_2)}
              GROUP BY
                YEAR(convert_tz(release_date, "UTC", "#{get_time_zone}")),
                MONTH(convert_tz(release_date, "UTC", "#{get_time_zone}"))
            )
          ) AS tbl
        GROUP BY
          division_number,
          division_name,
          range_year,
          range_month
      SQL
    end

    def make_range_field_sql range_field, year_1, year_2
      <<-SQL
        (
          (
            (
              #{range_field} >= '#{format_jan_1_date(year_1)}' AND
              #{range_field} < '#{format_jan_1_date(year_1 + 1)}'
            ) OR (
              #{range_field} >= '#{format_jan_1_date(year_2)}' AND
              #{range_field} < '#{format_jan_1_date(year_2 + 1)}'
            )
          ) AND
          #{range_field} < '#{format_first_day_of_current_month}'
        )
      SQL
    end

    def format_jan_1_date year
      ActiveSupport::TimeZone[get_time_zone].parse("#{year}-01-01").to_s(:db)
    end

    def format_first_day_of_current_month
      current_date = ActiveSupport::TimeZone[get_time_zone].now
      ActiveSupport::TimeZone[get_time_zone].parse("#{current_date.year}-#{current_date.month}-01").to_s(:db)
    end

    def get_time_zone
      "America/New_York"
    end

end; end; end
