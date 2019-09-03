require 'open_chain/report/report_helper'

module OpenChain; module Report; class PumaDivisionQuarterBreakdown
  include OpenChain::Report::ReportHelper

  PUMA_DIVISION_QUARTER_BREAKDOWN_USERS ||= 'puma_division_quarter_breakdown'

  PumaDivisionQuarterBreakdownRow ||= Struct.new(:total_entered_value, :total_invoice_value, :total_duty, :total_cotton_fee, :total_hmf, :total_mpf, :total_gst, :entry_count)

  def self.permission? user
    user.in_group?(Group.use_system_group(PUMA_DIVISION_QUARTER_BREAKDOWN_USERS, create: false))
  end

  def self.run_report run_by, settings
    self.new.run_breakdown settings
  end

  def run_breakdown settings
    year = settings['year'].to_i

    workbook = nil
    distribute_reads do
      workbook = generate_report year
    end

    file_name = "Puma_Division_Quarter_Breakdown_#{year}.xlsx"
    workbook_to_tempfile(workbook, "Puma Division Quarter Breakdown", file_name: "#{file_name}")
  end

  private
    def generate_report year
      wb = XlsxBuilder.new
      assign_styles wb
      sheet = wb.create_sheet "#{year} Breakdown"

      division_quarter_hash = {}

      result_set = ActiveRecord::Base.connection.exec_query make_query(year)
      result_set.each do |result_set_row|
        importer_sort_order = result_set_row['importer_sort_order']
        quarter = result_set_row['quarter']

        row = PumaDivisionQuarterBreakdownRow.new
        division_quarter_hash[[importer_sort_order, quarter]] = row

        row.total_entered_value = result_set_row['total_entered_value']
        row.total_invoice_value = result_set_row['total_invoice_value']
        row.total_duty = result_set_row['total_duty']
        row.total_cotton_fee = result_set_row['total_cotton_fee']
        row.total_hmf = result_set_row['total_hmf']
        row.total_mpf = result_set_row['total_mpf']
        row.total_gst = result_set_row['total_gst']
        row.entry_count = result_set_row['entry_count']
      end

      # CGOLF
      wb.add_body_row sheet, ["CGOLF"], styles:[:bold]
      wb.add_body_row sheet, make_us_headers, styles: Array.new(8, :default_header)
      wb.add_body_row sheet, make_us_row_for_division_quarter(division_quarter_hash[[1,1]], 1), styles: us_row_styles
      wb.add_body_row sheet, make_us_row_for_division_quarter(division_quarter_hash[[1,2]], 2), styles: us_row_styles
      wb.add_body_row sheet, make_us_row_for_division_quarter(division_quarter_hash[[1,3]], 3), styles: us_row_styles
      wb.add_body_row sheet, make_us_row_for_division_quarter(division_quarter_hash[[1,4]], 4), styles: us_row_styles
      wb.add_body_row sheet, make_us_totals_row(1, division_quarter_hash), styles: us_totals_row_styles
      wb.add_body_row sheet, []

      # PUMA USA
      wb.add_body_row sheet, ["PUMA USA"], styles:[:bold]
      wb.add_body_row sheet, make_us_headers, styles: Array.new(8, :default_header)
      wb.add_body_row sheet, make_us_row_for_division_quarter(division_quarter_hash[[2,1]], 1), styles: us_row_styles
      wb.add_body_row sheet, make_us_row_for_division_quarter(division_quarter_hash[[2,2]], 2), styles: us_row_styles
      wb.add_body_row sheet, make_us_row_for_division_quarter(division_quarter_hash[[2,3]], 3), styles: us_row_styles
      wb.add_body_row sheet, make_us_row_for_division_quarter(division_quarter_hash[[2,4]], 4), styles: us_row_styles
      wb.add_body_row sheet, make_us_totals_row(2, division_quarter_hash), styles: us_totals_row_styles
      wb.add_body_row sheet, []

      # PUMA CA
      wb.add_body_row sheet, ["PUMA CA"], styles:[:bold]
      wb.add_body_row sheet, make_ca_headers, styles: Array.new(6, :default_header)
      wb.add_body_row sheet, make_ca_row_for_division_quarter(division_quarter_hash[[3,1]], 1), styles: ca_row_styles
      wb.add_body_row sheet, make_ca_row_for_division_quarter(division_quarter_hash[[3,2]], 2), styles: ca_row_styles
      wb.add_body_row sheet, make_ca_row_for_division_quarter(division_quarter_hash[[3,3]], 3), styles: ca_row_styles
      wb.add_body_row sheet, make_ca_row_for_division_quarter(division_quarter_hash[[3,4]], 4), styles: ca_row_styles
      wb.add_body_row sheet, make_ca_totals_row(3, division_quarter_hash), styles: ca_totals_row_styles

      wb.set_column_widths sheet, *(Array.new(3, 20) + Array.new(6, 14))

      wb
    end

    def assign_styles wb
      wb.create_style :none, {}
      wb.create_style :bold, {b: true}
      wb.create_style(:currency, {format_code: "$#,##0.00"})
      wb.create_style(:currency_bold, {format_code: "$#,##0.00", b: true})
      wb.create_style(:number, {format_code: "#,##0"})
      wb.create_style(:number_bold, {format_code: "#,##0", b: true})
    end

    def us_row_styles
      [:none] + Array.new(6, :currency) + [:number]
    end

    def us_totals_row_styles
      [:bold] + Array.new(6, :currency_bold) + [:number_bold]
    end

    def ca_row_styles
      [:none] + Array.new(4, :currency) + [:number]
    end

    def ca_totals_row_styles
      [:bold] + Array.new(4, :currency_bold) + [:number_bold]
    end

    def make_us_row_for_division_quarter row_data, quarter
      if row_data
        ["Qtr #{quarter}", row_data.total_entered_value, row_data.total_invoice_value, row_data.total_duty, row_data.total_cotton_fee, row_data.total_hmf, row_data.total_mpf, row_data.entry_count]
      else
        ["Qtr #{quarter}", 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0]
      end
    end

    def make_ca_row_for_division_quarter row_data, quarter
      if row_data
        ["Qtr #{quarter}", row_data.total_entered_value, row_data.total_invoice_value, row_data.total_duty, row_data.total_gst, row_data.entry_count]
      else
        ["Qtr #{quarter}", 0.00, 0.00, 0.00, 0.00, 0]
      end
    end

    def make_us_headers
      ["", "Total Entered Value","Total Invoice Value","Total Duty","Cotton Fee","HMF","MPF","Entry Count"]
    end

    def make_ca_headers
      ["", "Total Entered Value","Total Invoice Value","Total Duty","Total GST","Entry Count"]
    end

    def make_us_totals_row division, division_quarter_hash
      ["Grand Totals:", get_total_value(:total_entered_value, division, division_quarter_hash),
          get_total_value(:total_invoice_value, division, division_quarter_hash), get_total_value(:total_duty, division, division_quarter_hash),
          get_total_value(:total_cotton_fee, division, division_quarter_hash), get_total_value(:total_hmf, division, division_quarter_hash),
          get_total_value(:total_mpf, division, division_quarter_hash), get_total_value(:entry_count, division, division_quarter_hash, decimal:false)]
    end

    def make_ca_totals_row division, division_quarter_hash
      ["Grand Totals:", get_total_value(:total_entered_value, division, division_quarter_hash),
          get_total_value(:total_invoice_value, division, division_quarter_hash), get_total_value(:total_duty, division, division_quarter_hash),
          get_total_value(:total_gst, division, division_quarter_hash), get_total_value(:entry_count, division, division_quarter_hash, decimal:false)]
    end

    def get_total_value field, division, division_quarter_hash, decimal:true
      total = decimal ? 0.00 : 0
      for quarter in 1..4 do
        val = division_quarter_hash[[division, quarter]].try(field)
        total += (val ? val : 0)
      end
      total
    end

    def make_query year
      qry = <<-SQL
          SELECT 
            (
              CASE sys_id.code
                WHEN 'CGOLF' THEN 1
                WHEN 'PUMA' THEN 2
                WHEN '892892654RM0001' THEN 3
              END
            ) AS importer_sort_order, 
            QUARTER(ent.release_date) AS quarter,
            IFNULL(SUM(ent.entered_value), 0) AS total_entered_value,
            IFNULL(SUM(ent.total_invoiced_value), 0) AS total_invoice_value,
            IFNULL(SUM(ent.total_duty), 0) AS total_duty,
            IFNULL(SUM(ent.cotton_fee), 0) AS total_cotton_fee,
            IFNULL(SUM(ent.hmf), 0) AS total_hmf,
            IFNULL(SUM(ent.mpf), 0) AS total_mpf,
            IFNULL(SUM(ent.total_gst), 0) AS total_gst,
            COUNT(DISTINCT ent.id) AS entry_count
          FROM 
            entries ent 
            INNER JOIN system_identifiers sys_id ON sys_id.company_id = ent.importer_id AND sys_id.system in ('Customs Management', 'Fenix') AND sys_id.code in ('PUMA','CGOLF', '892892654RM0001')
          WHERE
            ent.importer_id IN (?) AND 
            ent.release_date >= ? AND 
            ent.release_date < ?
          GROUP BY 
            importer_sort_order,
            QUARTER(ent.release_date)
          ORDER BY 
            importer_sort_order, 
            quarter
      SQL

      ActiveRecord::Base.sanitize_sql_array([qry, get_importer_ids, format_jan_1_date(year), format_jan_1_date(year + 1)])
    end

    def get_importer_ids
      importer_ids = Company.with_identifier(['Customs Management', 'Fenix'], ['PUMA','CGOLF', '892892654RM0001']).pluck(:id)
      importer_ids.length > 0 ? importer_ids : [-1]
    end

    def format_jan_1_date year
      ActiveSupport::TimeZone[get_time_zone].parse("#{year}-01-01").to_s(:db)
    end

    def get_time_zone
      "America/New_York"
    end

end; end; end