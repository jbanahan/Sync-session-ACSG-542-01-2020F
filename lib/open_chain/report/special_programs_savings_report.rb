require 'open_chain/report/report_helper'
module OpenChain; module Report; class SpecialProgramsSavingsReport
  include OpenChain::Report::ReportHelper

  def self.run_schedulable opts = {}
    raise "You must include at least one email in the email_to scheduled job parameter." if opts['email_to'].blank?

    time_zone = opts['time_zone'] || "America/New_York"

    Time.use_zone(time_zone) do
      start_date = 1.month.ago.beginning_of_month.to_s
      end_date = 1.month.ago.end_of_month.to_s

      opts['start_date'] = start_date
      opts['end_date'] = end_date

      workbook = self.run_report(User.integration, opts)
      OpenMailer.send_simple_html(opts['email_to'], "Special Programs Savings Report", "Report run on #{Time.zone.now}", workbook).deliver!
    end
  end

  def self.run_report run_by, opts = {}
    self.new.run(opts['companies'], opts['start_date'], opts['end_date'])
  end

  def self.permission? user
    user.company.master? && MasterSetup.get.custom_feature?('WWW VFI Track Reports')
  end

  def run(companies, release_date_start, release_date_end)
    parsed_companies = split_companies(companies)
    start_date, end_date = parse_date_parameters(release_date_start, release_date_end)
    sql = <<-SQL
      SELECT 
          e.customer_number AS 'Customer Number',
          e.broker_reference AS 'Broker Reference',
          e.entry_number AS 'Entry Number',
          e.release_date AS 'Release Date',
          c.iso_code AS 'Country ISO Code',
          ci.invoice_number AS 'Invoice-Invoice Number',
          cil.po_number AS 'Invoice Line - PO Number',
          cil.country_origin_code AS 'Invoice Line - Country Origin Code',
          cil.part_number AS 'Invoice Line - Part Number',
          cit.hts_code AS 'Invoice Tariff - HTS Code',
          cit.tariff_description AS 'Invoice Tariff - Description',
          IFNULL(cit.entered_value_7501, ROUND(cit.entered_value, 0)) AS 'Invoice Tariff - 7501 Entered Value',
          cit.duty_rate AS 'Invoice Tariff - Duty Rate',
          cit.duty_amount AS 'Invoice Tariff - Duty',
          cit.spi_primary AS 'SPI (Primary)',
          ot.common_rate_decimal AS 'Common Rate',
          IFNULL(ROUND((ot.common_rate_decimal * IFNULL(cit.entered_value_7501, cit.entered_value)), 2), 0) AS 'Duty without SPI',
          IFNULL(ROUND(ot.common_rate_decimal * IFNULL(cit.entered_value_7501, cit.entered_value), 2) - cit.duty_amount, 0) AS 'Savings'
      FROM
          entries e
              INNER JOIN
          countries c ON e.import_country_id = c.id
              INNER JOIN
          commercial_invoices ci ON e.id = ci.entry_id
              INNER JOIN
          commercial_invoice_lines cil ON ci.id = cil.commercial_invoice_id
              INNER JOIN
          commercial_invoice_tariffs cit ON cil.id = cit.commercial_invoice_line_id
              LEFT OUTER JOIN
          official_tariffs ot ON (cit.hts_code = ot.hts_code
              AND e.import_country_id = ot.country_id)
      WHERE
          e.customer_number IN (#{parsed_companies})
          AND e.release_date >= '#{start_date.to_s(:db)}'
          AND e.release_date < '#{end_date.to_s(:db)}'
      ORDER BY c.iso_code , e.customer_number , e.release_date
    SQL

    conversions = {"Release Date" => lambda{|row, value| value.nil? ? "" : value.in_time_zone(Time.zone).to_date},
                   "Invoice Tariff - Duty" => lambda{|row, value| grand_total_hash[:invoice_tariff_duty] += BigDecimal(value); value},
                   "Duty without SPI" => lambda{|row, value| grand_total_hash[:duty_without_spi] += BigDecimal(value); value},
                   "Savings" => lambda{|row, value| grand_total_hash[:savings] += BigDecimal(value); value}}

    wb = Spreadsheet::Workbook.new
    sheet = wb.create_worksheet :name=>"Savings Report"
    table_from_query sheet, sql, conversions
    sheet.row(sheet.rows.count + 1).replace(['Grand Totals', nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
                                         grand_total_hash[:invoice_tariff_duty], nil, nil, grand_total_hash[:duty_without_spi], grand_total_hash[:savings]])
    format = Spreadsheet::Format.new :vertical_align => :justify
    msg = "Common Rate and Duty without SPI is estimated based on the country’s current tariff schedule and may not reflect the historical Common Rate from the date the entry was cleared. For Common Rates with a compound calculation (such as 4% plus $0.05 per KG), only the percentage is used for the estimated Duty without SPI and Savings calculations."
    current_row = sheet.rows.count + 1
    sheet.merge_cells(current_row, 0, current_row + 4, 6)
    sheet.row(current_row).insert(0, msg)
    sheet.row(current_row).default_format = format
    workbook_to_tempfile wb, "Special Programs Savings Report"
  end

  private

  def grand_total_hash
    @grand_total_hash ||= Hash.new(BigDecimal(0))
  end

  def parse_date_parameters(start_date, end_date)
    [Time.zone.parse(start_date), Time.zone.parse(end_date)]
  end

  def split_companies(companies)
    if companies.is_a?(Array)
      companies = companies.join("\n")
    end
    companies.split("\n").map { |str| ActiveRecord::Base.connection.quote(str.strip) }.join(',')
  end
end; end; end