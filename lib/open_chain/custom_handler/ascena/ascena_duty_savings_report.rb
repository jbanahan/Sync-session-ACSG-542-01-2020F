require 'open_chain/report/report_helper'
require 'open_chain/fiscal_calendar_scheduling_support'

module OpenChain; module CustomHandler; module Ascena; class AscenaDutySavingsReport
  extend OpenChain::FiscalCalendarSchedulingSupport
  include OpenChain::Report::ReportHelper

  def self.permission? user
    importer = ascena
    return false unless importer

    (MasterSetup.get.system_code == "www-vfitrack-net" || Rails.env.development?) && 
    (user.view_entries? && (user.company.master? || importer.can_view?(user)))
  end

  def self.ascena
    Company.importers.where(alliance_customer_number: "ASCE").first
  end

  def self.fiscal_month settings
    if settings['fiscal_month'].to_s =~ /(\d{4})-(\d{2})/
      year = $1
      month = $2
      FiscalMonth.where(company_id: ascena.id, year: year.to_i, month_number: month.to_i).first
    else
      nil
    end
  end

  def self.run_report run_by, settings = {}
    fm = fiscal_month settings
    
    raise "No fiscal month configured for Ascena for #{fiscal_year}-#{fiscal_month}." unless fm

    self.new.run(fm)
  end

  def self.run_schedulable config = {}
    email_to = Array.wrap(config['email'])
    raise "At least one email must be present." unless email_to.length > 0

    run_if_configured(config) do |fiscal_month, fiscal_date, config|
      self.new.run(fiscal_month) do |report|
        body = "Attached is the Duty Savings Report for #{fiscal_month.fiscal_descriptor}."
        OpenMailer.send_simple_html(email_to, "Duty Savings Report #{fiscal_month.fiscal_descriptor}", body, report)
      end
    end
  end

  def run fiscal_month
    wb, summary = XlsMaker.create_workbook_and_sheet "Summary", summary_headers
    first_sale = XlsMaker.create_sheet wb, "First Sale", brand_headers
    data = XlsMaker.create_sheet wb, "Data", data_headers
    
    summary_data, first_sale_data = generate_data_tab data, fiscal_month.start_date, fiscal_month.end_date
    generate_summary_tab summary, summary_data
    generate_first_sale_brand_summary first_sale, first_sale_data

    if block_given?
      workbook_to_tempfile(wb, "DutySavings", file_name: "Duty Savings Report #{fiscal_month.fiscal_descriptor}.xls") do |f|
        yield f
      end
    else
      workbook_to_tempfile(wb, "DutySavings", file_name: "Duty Savings Report #{fiscal_month.fiscal_descriptor}.xls")
    end
  end

  def generate_data_tab sheet, start_date, end_date
    result_set = ActiveRecord::Base.connection.execute query(start_date, end_date)

    column_widths = []
    row_number = 0

    summary = {}
    first_sale_brand_summary = {}
    entries = Set.new

    result_set.each do |row|
      savings = calculate_duty_savings row
      calculations = savings[:calculations]

      # append the savings calculations to the row...
      row << calculations[:calculated_entered_value]
      row << calculations[:calculated_duty]
      row << calculations[:savings]

      XlsMaker.add_body_row sheet, (row_number += 1), row, column_widths, true

      # Now record any savings
      title = savings[:savings_title]
      if !title.blank?
        summary[title] ||= {entry_count: 0, entered_value: BigDecimal("0"), duty_paid: BigDecimal("0"), calculated_entered_value: BigDecimal("0"), calculated_duty: BigDecimal("0"), duty_savings: BigDecimal("0")}
        
        s = summary[title]
        broker_reference = row[field_map[:broker_reference]]
        s[:entry_count] += 1 unless entries.include?(broker_reference)
        s[:entered_value] += row[field_map[:entered_value]]
        s[:duty_paid] += row[field_map[:duty_amount]]
        s[:calculated_entered_value] += calculations[:calculated_entered_value]
        s[:calculated_duty] += calculations[:calculated_duty]
        s[:duty_savings] += calculations[:savings]

        entries << broker_reference
      end

      brand = row[field_map[:brand]]
      if !brand.blank?
        first_sale_brand_summary[brand] ||= {vendor_invoice: BigDecimal("0"), entered_value: BigDecimal("0"), total_entered_value: BigDecimal("0"), duty_savings: BigDecimal("0")}
        bs = first_sale_brand_summary[brand]

        if savings[:savings_type] == :first_sale
          bs[:vendor_invoice] += row[field_map[:first_sale_amount]]
          bs[:entered_value] += row[field_map[:entered_value]]
          bs[:duty_savings] += calculations[:savings]
          # For the total entered value, consider the first sale as the entered value on first sale lines
          bs[:total_entered_value] += calculations[:calculated_entered_value]
        else
          bs[:total_entered_value] += row[field_map[:entered_value]]
        end
      end
    end

    [summary, first_sale_brand_summary]
  end

  def generate_summary_tab sheet, summary
    column_widths = []
    row_number = 0

    summary.keys.sort.each do |title|
      summary_data = summary[title]

      raw_percentage = (summary_data[:duty_paid] / summary_data[:calculated_duty]).round(4)

      # If raw percentage is actually over 1, it means there was actually a loss and not a savings
      # (Not sure if this is actually possible, but just code for it)
      if raw_percentage > 1.0
        savings_percentage = (raw_percentage - BigDecimal("1")) * BigDecimal("-100")
      else
        savings_percentage = (BigDecimal("1") - raw_percentage) * BigDecimal("100")
      end

      row = [title, summary_data[:entry_count], summary_data[:entered_value], summary_data[:duty_paid], summary_data[:calculated_entered_value], summary_data[:calculated_duty], summary_data[:duty_savings], savings_percentage]

      XlsMaker.add_body_row sheet, (row_number += 1), row, column_widths
    end
  end

  def generate_first_sale_brand_summary sheet, summary
    column_widths = []

    XlsMaker.add_body_row sheet, 1, ["Vendor Invoice", summary["JST"].try(:[], :vendor_invoice), "", summary["LB"].try(:[], :vendor_invoice), "", summary["CA"].try(:[], :vendor_invoice), "", summary["MAU"].try(:[], :vendor_invoice), "", summary["DB"].try(:[], :vendor_invoice)]
    XlsMaker.add_body_row sheet, 2, ["Entered Value", summary["JST"].try(:[], :entered_value), "", summary["LB"].try(:[], :entered_value), "", summary["CA"].try(:[], :entered_value), "", summary["MAU"].try(:[], :entered_value), "", summary["DB"].try(:[], :entered_value)]
    XlsMaker.add_body_row sheet, 3, ["Duty Savings", summary["JST"].try(:[], :duty_savings), "", summary["LB"].try(:[], :duty_savings), "", summary["CA"].try(:[], :duty_savings), "", summary["MAU"].try(:[], :duty_savings), "", summary["DB"].try(:[], :duty_savings)]
    XlsMaker.add_body_row sheet, 4, ["Total Brand FOB Receipts", summary["JST"].try(:[], :total_entered_value), "", summary["LB"].try(:[], :total_entered_value), "", summary["CA"].try(:[], :total_entered_value), "", summary["MAU"].try(:[], :total_entered_value), "", summary["DB"].try(:[], :total_entered_value)]
  end

  def summary_headers
    ["Program Name", "Entry Count", "Total Entered Value", "Total Duty Paid", "Total Calculated Entered Value", "Total Calculated Duty", "Duty Savings", "Duty Savings Percentage"]
  end

  def data_headers
    ["Broker Reference", "Transport Mode Code", "Fiscal Month", "Release Date", "Invoice Number", "PO Number", "Part Number", "Brand", "Non-Dutiable Amount", "First Sale Cost", "HTS Code", "Tariff Description", "Entered Value", "SPI", "Duty Rate", "Duty Amount", "Calculated Entered Value", "Calculated Duty", "Duty Savings"]
  end

  def brand_headers
    ["", "Tweenbrands", "", "Lane Bryant", "", "Catherines", "", "Maurices", "", "Dressbarn"]
  end

  def calculate_duty_savings report_row
    savings_type, title = duty_savings_type(report_row)

    calculations = case savings_type
    when :air_sea, :other
      calculate_air_sea_differential(report_row)
    when :first_sale
      calculate_first_sale(report_row)
    when :spi
      calculate_spi(report_row)
    else
      # No duty savings, so just put values from the actual entry back into the calculations so the data has something in the display
      # columns for those.
      {calculated_entered_value: report_row[field_map[:entered_value]], calculated_duty: report_row[field_map[:duty_amount]], savings: 0}
    end

    {savings_type: savings_type, savings_title: title, calculations: calculations}
  end

  def calculate_air_sea_differential report_row
    calculated_entered_value = report_row[field_map[:non_dutiable_amount]] + report_row[field_map[:entered_value]]
    calculated_duty = (calculated_entered_value * report_row[field_map[:duty_rate]]).round(2)
    savings = calculated_duty - report_row[field_map[:duty_amount]]

    {calculated_entered_value: calculated_entered_value, calculated_duty: calculated_duty, savings: savings}
  end

  def calculate_first_sale report_row
    calculated_entered_value = report_row[field_map[:first_sale_amount]]
    calculated_duty = (calculated_entered_value * report_row[field_map[:duty_rate]]).round(2)
    savings = calculated_duty - report_row[field_map[:duty_amount]]

    {calculated_entered_value: calculated_entered_value, calculated_duty: calculated_duty, savings: savings}
  end

  def calculate_spi report_row
    non_spi_duty_rate = common_duty_rate(report_row[field_map[:hts_code]])
    # If there's an actual duty rate for this hts, then we can calculate savings
    if non_spi_duty_rate.to_f > 0
      entered_value = report_row[field_map[:entered_value]]
      calculated_duty = (entered_value * non_spi_duty_rate).round(2)
      savings = calculated_duty - report_row[field_map[:duty_amount]]

      {calculated_entered_value: entered_value, calculated_duty: calculated_duty, savings: savings}
    else
      {calculated_entered_value: report_row[field_map[:entered_value]], calculated_duty: report_row[field_map[:duty_rate]], savings: 0}
    end
  end

  def duty_savings_type report_row
    if !report_row[field_map[:spi]].blank?
      [:spi, spi_name(report_row[field_map[:spi]])]
    elsif report_row[field_map[:transport_mode_code]].to_s == "40" && report_row[field_map[:non_dutiable_amount]].to_f > 0
      [:air_sea, "Air Sea Differential"]
    elsif report_row[field_map[:transport_mode_code]].to_s != "40" && report_row[field_map[:non_dutiable_amount]].to_f > 0
      [:other, "Other"]
    elsif report_row[field_map[:first_sale_amount]].to_f > 0
      [:first_sale, "First Sale"]
    else
      nil
    end
  end

  def spi_name spi
    spis = {"AU" => "Australia FTA", "BH" => "Bahrain FTA", "CA" => "CA NAFTA", "CL" => "Chile FTA", "CO" => "Columbia", "D" => "AGOA", "E" => "CBI", "IL" => "Israel FTA",
     "JO" => "Jordan FTA", "KR" => "Korea FTA", "MA" => "Morocco FTA", "MX" => "MX NAFTA", "OM" => "Oman FTA", "P" => "CAFTA", "P+" => "CAFTA", "PA" => "Panama FTA", 
     "PE" => "Peru FTA", "R" => "CBTPA", "SG" => "Singapore FTA"}

    label = spis[spi.to_s.upcase]
    label.blank? ? spi : label
  end

  def common_duty_rate hts
    @rate ||= Hash.new do |h, k|
      ot = OfficialTariff.where(country_id: us.id, hts_code: hts).first
      h[k] = ot.try(:common_rate_decimal)
    end

    @rate[hts]
  end

  def us
    @us ||= Country.where(iso_code: "US").first
    raise "Failed to find 'US' country record" unless @us

    @us
  end

  def query start_date, end_date
    qry = <<-QRY
SELECT e.broker_reference, e.transport_mode_code, concat(fiscal_year, '-', lpad(fiscal_month, 2, '0')), convert_tz(e.release_date, 'UTC', 'America/New_York'), i.invoice_number, l.po_number, l.part_number, l.product_line, l.non_dutiable_amount, l.contract_amount, t.hts_code, t.tariff_description, t.entered_value, t.spi_primary, t.duty_rate, t.duty_amount
FROM entries e
INNER JOIN commercial_invoices i on e.id = i.entry_id
INNER JOIN commercial_invoice_lines l on i.id = l.commercial_invoice_id
INNER JOIN commercial_invoice_tariffs t on t.commercial_invoice_line_id = l.id
WHERE e.customer_number = 'ASCE' AND e.source_system = 'Alliance' AND e.fiscal_date >= '#{start_date}' and e.fiscal_date < '#{end_date}'
QRY
  end

  def field_map
    @map ||= {broker_reference: 0, transport_mode_code: 1, fiscal_date: 2, release_date: 3, invoice_number: 4, po_number: 5, part_number: 6, brand: 7, non_dutiable_amount: 8, first_sale_amount: 9, hts_code: 10, tariff_description: 11, entered_value: 12, spi: 13, duty_rate: 14, duty_amount: 15}
  end

end; end; end; end;