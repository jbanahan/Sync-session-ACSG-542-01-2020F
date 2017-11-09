require 'open_chain/report/report_helper'
require 'open_chain/fiscal_calendar_scheduling_support'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; module Ascena; class AscenaDutySavingsReport
  extend OpenChain::FiscalCalendarSchedulingSupport
  include OpenChain::Report::ReportHelper
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  #sets both the brands that are included and the order in which they appear in the first-sale tab
  BRAND_MAP = {"JST" => "Justice", "LB" => "Lane Bryant", "CA" => "Catherines", "MAU" => "Maurices", "DB" => "Dressbarn"}

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

    run_if_configured(config) do |fiscal_month, fiscal_date|
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
    first_sale_brand_summary = {"AGS" => {}, "NONAGS" => {}}
    entries = Hash.new{ |h,k| h[k] = Set.new }

    result_set.each do |row|
      savings_set = calculate_duty_savings row

      # append the savings calculations to the row...
      row << savings_set.map{|s| s[:calculations][:calculated_entered_value]}.sum
      row << savings_set.map{|s| s[:calculations][:calculated_duty]}.sum
      row << savings_set.map{|s| s[:calculations][:savings]}.sum

      XlsMaker.add_body_row sheet, (row_number += 1), row, column_widths, true

      savings_set.each do |savings|
        # Now record any savings
        title = savings[:savings_title]
        if !title.blank?
          summary[title] ||= {entry_count: 0, entered_value: BigDecimal("0"), duty_paid: BigDecimal("0"), calculated_entered_value: BigDecimal("0"), calculated_duty: BigDecimal("0"), duty_savings: BigDecimal("0")}
          
          s = summary[title]
          broker_reference = row[field_map[:broker_reference]]
          
          calculations = savings[:calculations]
          s[:entry_count] += 1 unless entries[title].include?(broker_reference)
          s[:entered_value] += row[field_map[:entered_value]]
          s[:duty_paid] += row[field_map[:duty_amount]]
          s[:calculated_entered_value] += calculations[:calculated_entered_value]
          s[:calculated_duty] += calculations[:calculated_duty]
          s[:duty_savings] += calculations[:savings]

          entries[title] << broker_reference
        end
      end

      brand = row[field_map[:brand]]
      if BRAND_MAP.keys.member?(brand)
        order_type = row[field_map[:order_type]].to_s.strip.upcase == "NONAGS" ? "NONAGS" : "AGS"

        first_sale_brand_summary[order_type][brand] ||= {vendor_invoice: BigDecimal("0"), entered_value: BigDecimal("0"), total_entered_value: BigDecimal("0"), duty_savings: BigDecimal("0")}
        bs = first_sale_brand_summary[order_type][brand]
        savings_set.each do |savings|
          calculations = savings[:calculations]
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
        bs[:total_entered_value] += row[field_map[:entered_value]] if savings_set.empty?
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

  def generate_first_sale_brand_summary sheet, brand_summary
    row = 0
    [["AGS", brand_summary["AGS"]], ["NONAGS", brand_summary["NONAGS"]]].each do |summary_type, summary|
     
      XlsMaker.add_body_row sheet, (row+=1), first_sale_brand_summary_row(summary, summary_type, "Vendor Invoice", :vendor_invoice)
      XlsMaker.add_body_row sheet, (row+=1), first_sale_brand_summary_row(summary, summary_type, "Entered Value", :entered_value)
      XlsMaker.add_body_row sheet, (row+=1), first_sale_brand_summary_row(summary, summary_type, "Duty Savings", :duty_savings)
      XlsMaker.add_body_row sheet, (row+=1), first_sale_brand_summary_row(summary, summary_type, "Total Brand FOB Receipts", :total_entered_value)
      row+=1
    end
    
  end

  def first_sale_brand_summary_row summary, summary_type, summary_field_name, summary_field
    out = [summary_type + " " + summary_field_name]
    BRAND_MAP.keys.each { |b| out << summary[b].try(:[], summary_field) << "" }
    out[0..-2] #trim extra blank
  end

  def summary_headers
    ["Program Name", "Entry Count", "Total Entered Value", "Total Duty Paid", "Total Calculated Entered Value", "Total Calculated Duty", "Duty Savings", "Duty Savings Percentage"]
  end

  def data_headers
    ["Broker Reference", "Transport Mode Code", "Fiscal Month", "Release Date", "Invoice Number", "PO Number", "Part Number", "Brand", "Non-Dutiable Amount", "First Sale Cost", "Invoice Line Value", "HTS Code", "Tariff Description", "Entered Value", "SPI", "Duty Rate", "Duty Amount", "Order Type", "Calculated Entered Value", "Calculated Duty", "Duty Savings"]
  end

  def brand_headers
    BRAND_MAP.map{ |k,v| ["", v] }.flatten
  end

  def calculate_duty_savings report_row
    types = duty_savings_type(report_row)
    savings = []
    if types.empty?
      # No duty savings, so just put values from the actual entry back into the calculations so the data has something in the display
      # columns for those.
      calculations = {calculated_entered_value: report_row[field_map[:entered_value]], calculated_duty: report_row[field_map[:duty_amount]], savings: 0}
      savings << {savings_type: nil, savings_title: nil, calculations: calculations}
    else
      types.each do |t|
        savings_type, title = t
        calculations = case savings_type
          when :air_sea, :other
            calculate_air_sea_differential(report_row)
          when :first_sale
            calculate_first_sale(report_row)
          when :spi
            calculate_spi(report_row)
          end
        savings << {savings_type: savings_type, savings_title: title, calculations: calculations}
      end
    end

    savings
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
    savings = (calculate_fs_duty_savings report_row).round(2)
    {calculated_entered_value: calculated_entered_value, calculated_duty: calculated_duty, savings: savings}
  end

  def calculate_fs_duty_savings row
    return 0 if [0,nil].member?(row[field_map[:first_sale_amount]]) || [0,nil].member?(row[field_map[:entered_value]])
    (row[field_map[:first_sale_amount]] - row[field_map[:value]]) * (row[field_map[:duty_amount]] / row[field_map[:entered_value]])
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
    types = []
    types << [:spi, spi_name(report_row[field_map[:spi]])] if report_row[field_map[:spi]].present?
    types << [:air_sea, "Air Sea Differential"] if report_row[field_map[:transport_mode_code]].to_s == "40" && report_row[field_map[:non_dutiable_amount]].to_f > 0
    types << [:other, "Other"] if report_row[field_map[:transport_mode_code]].to_s != "40" && report_row[field_map[:non_dutiable_amount]].to_f > 0
    types << [:first_sale, "First Sale"] if report_row[field_map[:first_sale_amount]].to_f > 0
    types
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
    <<-SQL
      SELECT e.broker_reference, 
             e.transport_mode_code, 
             concat(fiscal_year, '-', lpad(fiscal_month, 2, '0')), 
             convert_tz(e.release_date, 'UTC', 'America/New_York'), 
             i.invoice_number, 
             l.po_number, 
             l.part_number, 
             l.product_line, 
             l.non_dutiable_amount, 
             l.contract_amount, 
             l.value,
             t.hts_code, 
             t.tariff_description, 
             t.entered_value, 
             t.spi_primary, 
             t.duty_rate, 
             t.duty_amount, 
             ord_type.string_value
      FROM entries e
      INNER JOIN commercial_invoices i on e.id = i.entry_id
      INNER JOIN commercial_invoice_lines l on i.id = l.commercial_invoice_id
      INNER JOIN commercial_invoice_tariffs t on t.commercial_invoice_line_id = l.id
      LEFT OUTER JOIN orders o ON o.order_number = CONCAT("ASCENA-", l.po_number)
      LEFT OUTER JOIN custom_values ord_type ON ord_type.customizable_id = o.id AND ord_type.customizable_type = "Order" AND ord_type.custom_definition_id = #{cdefs[:ord_type].id}
      WHERE e.customer_number = 'ASCE' AND e.source_system = 'Alliance' AND e.fiscal_date >= '#{start_date}' and e.fiscal_date < '#{end_date}'
    SQL
  end

  def field_map
    @map ||= {broker_reference: 0, transport_mode_code: 1, fiscal_date: 2, release_date: 3, invoice_number: 4, po_number: 5, part_number: 6, brand: 7, non_dutiable_amount: 8, first_sale_amount: 9, value: 10, hts_code: 11, tariff_description: 12, entered_value: 13, spi: 14, duty_rate: 15, duty_amount: 16, order_type: 17}
  end

  def cdefs 
    @cdefs ||= self.class.prep_custom_definitions [:ord_type]
  end

end; end; end; end;