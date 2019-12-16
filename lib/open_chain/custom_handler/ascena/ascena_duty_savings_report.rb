require 'open_chain/fiscal_calendar_scheduling_support'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/custom_handler/ascena/ascena_report_helper'

module OpenChain; module CustomHandler; module Ascena; class AscenaDutySavingsReport
  extend OpenChain::FiscalCalendarSchedulingSupport
  include OpenChain::CustomHandler::Ascena::AscenaReportHelper

  attr_accessor :cust_numbers
  
  # Maurices began as a brand of Ascena and was later split out into a separate importer, but the old brand entries
  # still have to be handled along with the newer importer ones. Handling of Maurices (importer) is the same as 
  # Ascena except for two differences: (1) Ascena entries join the order using product_line, while Maurices uses a hard-coded "-MAU-"
  # infix (this is confusing because the order number format is indistinguishable from one joined to a Maurices-branded Ascena entry). 
  # (2) In the First-Sale tab all Maurices importer data appears under the 'Maurices-Maur' column, ignoring the product_line field 
  # (which is also how Ann is handled)

  #sets both the brands that are included and the order in which they appear in the first-sale tab
  ASCENA_BRAND_MAP = {"JST" => "Justice", "LB" => "Lane Bryant", "CA" => "Catherines", "MAU" => "Maurices", "DB" => "Dressbarn"}
  SUMMARY_NAME_MAP = { ANN_CUST_NUM => "Ann Inc. Summary", ASCENA_CUST_NUM => "ATS Summary", MAURICES_CUST_NUM => "Maurices Summary"}
  HELPER_PREFIX = OpenChain::CustomHandler::Ascena::AscenaReportHelper
  

  def self.cust_info
    CUST_INFO
  end

  def self.run_report run_by, settings = {}
    fm = fiscal_month settings
    
    raise "No fiscal month configured for Ascena for #{fiscal_year}-#{fiscal_month}." unless fm

    self.new(settings['cust_numbers']).run fm
  end

  def self.run_schedulable config = {}
    config['email'] = Array.wrap(config['email'])
    config['cust_numbers'] = Array.wrap(config['cust_numbers'])
    raise "Scheduled instances of the Ascena / Ann /Maurices Duty Savings Report must include an email setting with at least one email address." unless config['email'].length > 0
    raise "Scheduled instances of the Ascena / Ann /Maurices Duty Savings Report must include a cust_numbers setting with at least one customer number." unless config['cust_numbers'].length > 0
    # Sets the fiscal calendar
    config['company'] = 'ASCENA'
    run_if_configured(config) do |fiscal_month, fiscal_date|
      fm = fiscal_month.back(1)
      self.new(config['cust_numbers']).run(fm) do |report|
        cust_names = cust_nums_to_short_names(config['cust_numbers'])
        body = "Attached is the #{cust_names} Duty Savings Report for #{fm.fiscal_descriptor}."
        OpenMailer.send_simple_html(config['email'], "#{cust_names} Duty Savings Report #{fm.fiscal_descriptor}", body, report).deliver_now
      end
    end
  end

  def initialize cust_numbers
    @cust_numbers = Array.wrap(cust_numbers).sort
    # This is a hack. Bryan Wolfe at Ann expects the "Total Calculated Invoice Value" from the "Actual Entry Totals" row to match 
    # "NONAGS Total Brand FOB Receipts". Until we figure out why, this serves as a global var for taking a value from one tab and copying
    # it to another
    @ann_entry_total_calculated_invoice_value = nil
  end

  def brand_map
    map = {}
    cust_numbers.each do |cn|
      map.merge!(ASCENA_BRAND_MAP) if cn == ASCENA_CUST_NUM
      map.merge!(ANN_CUST_NUM => "Ann Inc.") if cn == ANN_CUST_NUM
      map.merge!(MAURICES_CUST_NUM => "Maurices-Maur") if cn == MAURICES_CUST_NUM
    end
    map
  end

  def run fiscal_month
    wb, summaries = create_workbook
    first_sale = XlsMaker.create_sheet wb, "First Sale", brand_headers
    data_sheet = XlsMaker.create_sheet wb, "Data", data_headers
    
    raw_result_set = Query.new.run(cust_numbers, fiscal_month.start_date, fiscal_month.end_date)
    summary_data = generate_summary_data raw_result_set
    first_sale_data = generate_first_sale_data raw_result_set
    generate_data_tab raw_result_set, data_sheet 
    generate_summary_tabs summaries, summary_data
    generate_first_sale_tab first_sale, first_sale_data
    cust_names = self.class.cust_nums_to_short_names(@cust_numbers)

    if block_given?
      workbook_to_tempfile(wb, "DutySavings", file_name: "#{cust_names} Duty Savings Report #{fiscal_month.fiscal_descriptor}.xls") do |f|
        yield f
      end
    else
      workbook_to_tempfile(wb, "DutySavings", file_name: "#{cust_names} Duty Savings Report #{fiscal_month.fiscal_descriptor}.xls")
    end
  end

  def create_workbook
    cnums = cust_numbers.dup
    wb, first_sheet = XlsMaker.create_workbook_and_sheet SUMMARY_NAME_MAP[cnums.shift], summary_headers
    sheets = [first_sheet]
    cnums.each { |n| sheets.push(XlsMaker.create_sheet wb, SUMMARY_NAME_MAP[n], summary_headers) }
    [wb, sheets]
  end

  def generate_data_tab result_set, sheet
    column_widths = []
    row_number = 0
    formats = data_tab_formats
    result_set.each { |row| XlsMaker.add_body_row sheet, (row_number += 1), row.to_a[0..59], column_widths, true, formats: formats }
    nil
  end

  def data_tab_formats
    columns = Array.new(60, nil)
    currency_columns = [:original_fob_unit_value, :original_fob_entered_value, :duty, :first_sale_difference, :first_sale_duty_savings,
                        :price_before_discounts, :line_entered_value, :air_sea_discount, :air_sea_per_unit_savings, :air_sea_duty_savings, :early_payment_discount, 
                        :epd_per_unit_savings, :epd_duty_savings, :trade_discount, :trade_discount_per_unit_savings, :trade_discount_duty_savings, :spi_duty_savings, 
                        :hanger_duty_savings, :mp_vs_air_sea, :mp_vs_epd, :mp_vs_trade_discount, :mp_vs_air_sea_epd_trade, :first_sale_savings, :air_sea_savings, :epd_savings, 
                        :trade_discount_savings]
    percentage_columns = [:duty_rate, :first_sale_margin_percent]

    currency_columns.each { |c| columns[Wrapper::FIELD_MAP[c]] = CURRENCY_FORMAT }
    percentage_columns.each{ |c| columns[Wrapper::FIELD_MAP[c]] = PERCENTAGE_FORMAT }
    columns 
  end

  def generate_first_sale_data result_set
    first_sale_brand_summary = {"AGS" => {}, "NONAGS" => {}}
    result_set.each do |row|      
      # Only Ascena has distinct brands, so tag every Ann and Maurices row the same
      brand = row.ann? ? ANN_CUST_NUM : (row.maurices? ? MAURICES_CUST_NUM : row[:product_line])
      if brand_map.keys.member?(brand)
        order_type = row[:order_type].to_s.strip.upcase == "NONAGS" ? "NONAGS" : "AGS"

        first_sale_brand_summary[order_type][brand] ||= {vendor_invoice: BigDecimal("0"), entered_value_7501: BigDecimal("0"), total_entered_value_7501: BigDecimal("0"), duty_savings: BigDecimal("0")}
        bs = first_sale_brand_summary[order_type][brand]
        savings_set = row.duty_savings
        savings_set.each do |savings|
          calculations = savings[:calculations]
          if savings[:savings_type] == :first_sale
            if !row.special_tariff?
              bs[:vendor_invoice] += row[:contract_amount]
              bs[:entered_value_7501] += row[:cil_entered_value_7501]
              # For the total entered value, consider the first sale as the entered value on first sale lines
              # Also: For some reason Ascena expects to see the non-dutiable amount as part of the "Total Brand FOB Receipts"
              bs[:total_entered_value_7501] += calculations[:calculated_invoice_value] + (row.ann? ? BigDecimal("0") : row[:non_dutiable_amount])
            end
            bs[:duty_savings] += calculations[:savings]
          elsif savings[:savings_type] != :line && !row.special_tariff?
            bs[:total_entered_value_7501] += row[:cil_entered_value_7501] + (row.ann? ? BigDecimal("0") : row[:non_dutiable_amount])
          end
        end
        bs[:total_entered_value_7501] += row[:cil_entered_value_7501] if savings_set.empty? && !row.special_tariff?
      end
    end
    # See note in #initialize
    ann_brand_summary = first_sale_brand_summary["NONAGS"][ANN_CUST_NUM]
    ann_brand_summary[:total_entered_value_7501] = @ann_entry_total_calculated_invoice_value if ann_brand_summary
      
    first_sale_brand_summary
  end
    
  def generate_summary_data result_set
    cust_numbers.map{ |n| generate_customer_summary_data(result_set, n) }
  end

  def generate_customer_summary_data result_set, cust_number
    summary = {}
    entries = Hash.new{ |h,k| h[k] = Set.new }

    result_set.each do |row|
      next unless row[:customer_number] == cust_number
      
      savings_set = row.duty_savings
      savings_set.each do |savings|
        # Now record any savings
        title = savings[:savings_title]
        if !title.blank?
          summary[title] ||= {usage_count: 0, entered_value_7501: BigDecimal("0"), duty_paid: BigDecimal("0"), calculated_invoice_value: BigDecimal("0"), calculated_duty: BigDecimal("0"), duty_savings: BigDecimal("0")}
          
          s = summary[title]
          broker_reference = row[:broker_reference]
          
          calculations = savings[:calculations]
          s[:usage_count] += 1 unless entries[title].include?(broker_reference)
          s[:entered_value_7501] += row[:cil_entered_value_7501] unless row.special_tariff?
          s[:duty_paid] += row[:duty_amount]
          s[:calculated_invoice_value] += calculations[:calculated_invoice_value] unless row.special_tariff?
          s[:calculated_duty] += calculations[:calculated_duty]
          s[:duty_savings] += calculations[:savings]
          entries[title] << broker_reference
        end
      end
    end
    
    # See note in #initialize
    if cust_number == ANN_CUST_NUM && summary.present?
      @ann_entry_total_calculated_invoice_value = summary["Actual Entry Totals"][:calculated_invoice_value] 
    end
    summary
  end

  def generate_summary_tabs sheets, summaries
    sheets.zip(summaries).each { |tuple| generate_customer_summary_tab tuple[0], tuple[1] }
  end

  def generate_customer_summary_tab sheet, summary
    column_widths = Array.new(9, 25)
    row_number = 0

    summary.keys.sort{ |a, b| summary_sorter a, b }.each do |title|
      summary_data = summary[title]

      raw_percentage = (summary_data[:duty_paid] / summary_data[:calculated_duty]).round(4)

      # If raw percentage is actually over 1, it means there was actually a loss and not a savings
      # (Not sure if this is actually possible, but just code for it)
      if raw_percentage > 1.0
        savings_percentage = (raw_percentage - BigDecimal("1")) * BigDecimal("-1")
      else
        savings_percentage = (BigDecimal("1") - raw_percentage)
      end

      row = [title, summary_data[:usage_count], summary_data[:entered_value_7501], summary_data[:duty_paid], summary_data[:calculated_invoice_value], summary_data[:calculated_duty], summary_data[:duty_savings], savings_percentage]

      XlsMaker.add_body_row sheet, (row_number += 1), row, column_widths, false, formats: [nil, nil] + Array.new(5, CURRENCY_FORMAT) + [PERCENTAGE_FORMAT]
    end
  end

  # ensures last two rows of summary tab are "Other", "Actual Entry Totals" (if they exist)
  def summary_sorter a, b
    if !["Other", "Actual Entry Totals"].include?(a) && !["Other", "Actual Entry Totals"].include?(b)
      a <=> b
    else
      return 1 if a == "Actual Entry Totals" || (a == "Other" && b != "Actual Entry Totals")
      -1
    end
  end

  def generate_first_sale_tab sheet, brand_summary
    row = 0
    column_widths = []
    formats =  Array.new(7, nil).zip(Array.new(7, CURRENCY_FORMAT)).flatten
    [["AGS", brand_summary["AGS"]], ["NONAGS", brand_summary["NONAGS"]]].each do |summary_type, summary|
     
      XlsMaker.add_body_row sheet, (row += 1), first_sale_brand_summary_row(summary, summary_type, "Vendor Invoice", :vendor_invoice), column_widths, false, formats: formats
      XlsMaker.add_body_row sheet, (row += 1), first_sale_brand_summary_row(summary, summary_type, "Entered Value", :entered_value_7501), column_widths, false, formats: formats
      XlsMaker.add_body_row sheet, (row += 1), first_sale_brand_summary_row(summary, summary_type, "Duty Savings", :duty_savings), column_widths, false, formats: formats
      XlsMaker.add_body_row sheet, (row += 1), first_sale_brand_summary_row(summary, summary_type, "Total Brand FOB Receipts", :total_entered_value_7501), column_widths, false, formats: formats
      row+=1
    end
  end

  def first_sale_brand_summary_row summary, summary_type, summary_field_name, summary_field
    out = [summary_type + " " + summary_field_name]
    brand_map.keys.each { |b| out << summary[b].try(:[], summary_field) << "" }
    out[0..-2] #trim extra blank
  end

  def summary_headers
    ["Program Name", "Entry Usage Count", "Total Entered Value", "Total Duty Paid", "Total Calculated Invoice Value", "Total Calculated Duty", "Duty Savings", "Duty Savings Percentage"]
  end

  def data_headers
    ["Broker Reference Number", "Importer", "First Sale", "Supplier", "Manufacturer", "Transactions Related", "Mode of Transport", "Fiscal Month", "Release Date", 
     "Filer", "Entry No.", "7501 Line Number", "Invoice Number", "Product Code", "PO Number", "Brand", "Order Type", "Country of Origin", "Country of Export", 
     "Arrival Date", "Import Date", "Arrival Port", "Entry Port", "Tariff", "Duty Rate", "Goods Description", "Price/Unit", "Invoice Quantity", "Invoice UOM", 
     "Original FOB Unit Value", "Original FOB Entered Value", "Duty", "First Sale Difference", "First Sale Duty Savings", "First Sale Margin %", 
     "Line Price Before Discounts", "Line Entered Value", "Air/Sea Discount", "Air/Sea Per Unit Savings", "Air/Sea Duty Savings", "Early Payment Discount", 
     "EPD per Unit Savings", "EPD Duty Savings", "Trade Discount", "Trade Discount per Unit Savings", "Trade Discount Duty Savings", "SPI", "Original Duty Rate", 
     "SPI Duty Savings", "Fish and Wildlife", "Hanger Duty Savings", "MP vs. Air/Sea", "MP vs. EPD", "MP vs. Trade Discount", "MP vs. Air/Sea/EPD Trade", 
     "First Sale Savings", "Air/Sea Savings", "EPD Savings", "Trade Discount Savings", "Applied Discount"]
  end

  def brand_headers
    brand_map.map{ |k,v| ["", v] }.flatten
  end

######################

  class Wrapper < RowWrapper
    attr_accessor :official_tariff

    FIELD_MAP = {broker_reference: 0, customer_name: 1, first_sale: 2, vendor: 3, factory: 4, related_parties: 5, transport_mode_code: 6, 
                 fiscal_month: 7, release_date: 8, filer: 9, entry_number: 10, custom_line_number: 11, invoice_number: 12, part_number: 13, 
                 po_number: 14, product_line: 15, order_type: 16, country_origin_code: 17, country_export_code: 18, arrival_date: 19, 
                 import_date: 20, arrival_port: 21, entry_port: 22, hts_code: 23, duty_rate: 24, goods_description: 25, unit_price: 26, 
                 quantity: 27, unit_of_measure: 28, original_fob_unit_value: 29, original_fob_entered_value: 30, duty: 31, first_sale_difference: 32,
                 first_sale_duty_savings: 33, first_sale_margin_percent: 34, price_before_discounts: 35, line_entered_value: 36, air_sea_discount: 37, 
                 air_sea_per_unit_savings: 38, air_sea_duty_savings: 39, early_payment_discount: 40, epd_per_unit_savings: 41, epd_duty_savings: 42, 
                 trade_discount: 43, trade_discount_per_unit_savings: 44, trade_discount_duty_savings: 45, spi: 46, original_duty_rate: 47,
                 spi_duty_savings: 48, fish_and_wildlife: 49, hanger_duty_savings: 50, mp_vs_air_sea: 51, mp_vs_epd: 52, mp_vs_trade_discount: 53, 
                 mp_vs_air_sea_epd_trade: 54, first_sale_savings: 55, air_sea_savings: 56, epd_savings: 57, trade_discount_savings: 58, 
                 applied_discount: 59, e_id: 60, import_country_id: 61, customer_number: 62, cil_id: 63, contract_amount: 64, non_dutiable_amount: 65, 
                 value: 66, quantity_attrib: 67, unit_of_measure_attrib: 68, cil_entered_value_7501: 69, miscellaneous_discount: 70, other_amount: 71,
                 duty_amount: 72, special_tariff: 73, air_sea_discount_attrib: 74, middleman_charge: 75, early_payment_discount_attrib: 76, trade_discount_attrib: 77}

    def initialize row
      super row, FIELD_MAP
    end

    def ascena?
      self[:customer_number] == HELPER_PREFIX::ASCENA_CUST_NUM
    end

    def maurices?
      self[:customer_number] == HELPER_PREFIX::MAURICES_CUST_NUM
    end
    
    def ann?
      self[:customer_number] == HELPER_PREFIX::ANN_CUST_NUM
    end

    def first_sale?
      self[:contract_amount] > 0
    end

    def special_tariff?
      !!self[:special_tariff]
    end

    # For Ann, cil.other_amount is stored as a negative value
    def other_amount
      val = self[:other_amount]
      self.ann? ? (val * -1) : val
    end

    def duty_savings
      @ds ||= DutySavingsCalculator.new(self).get
    end
  end
  
  class DutySavingsCalculator
    attr_reader :row
    
    def initialize row
      @row = row
    end

    def get
      types = DutySavingsType.new(row).get
      savings_set = []
      if types.empty?
        # No duty savings, so just put values from the actual entry back into the calculations so the data has something in the display
        # columns for those.
        calculated_invoice_value = !row.special_tariff? ? row[:cil_entered_value_7501] : BigDecimal("0")
        calculations = {calculated_invoice_value: calculated_invoice_value , calculated_duty: row[:duty_amount], savings: 0}
        savings_set << {savings_type: nil, savings_title: nil, calculations: calculations}
      else
        types.each do |t|
          savings_type, title = t
          calculations = case savings_type
            when :air_sea, :other
              calculate_air_sea_differential
            when :first_sale
              calculate_first_sale
            when :spi
              calculate_spi
            when :epd
              calculate_epd
            when :trade
              calculate_trade_discount
            end
          savings_set << {savings_type: savings_type, savings_title: title, calculations: calculations}
        end
        ActualEntryTotalCalculator.new(row, savings_set).fill_totals unless types.empty?
      end

      savings_set
    end

    def calculate_first_sale
      initial_invoice_value = row[:contract_amount]
      calculated_invoice_value = !row.special_tariff? ? initial_invoice_value : BigDecimal("0")
      calculated_duty = row.ann? ? (row[:duty] + row[:first_sale_savings]) : (initial_invoice_value * row[:duty_rate]).round(2)
      savings = row[:first_sale_duty_savings].round(2)
      {calculated_invoice_value: calculated_invoice_value, calculated_duty: calculated_duty, savings: savings}
    end
    
    def calculate_spi
      non_spi_duty_rate = row.official_tariff.try(:common_rate_decimal)
      initial_invoice_value = row[:cil_entered_value_7501]
      calculated_invoice_value = !row.special_tariff? ? initial_invoice_value : BigDecimal("0")
      # If there's an actual duty rate for this hts, then we can calculate savings
      if non_spi_duty_rate.to_f > 0
        calculated_duty = (initial_invoice_value * non_spi_duty_rate).round(2)
        savings =  spi_suspended? ? row[:duty_amount] : calculated_duty - row[:duty_amount]

        {calculated_invoice_value: calculated_invoice_value, calculated_duty: calculated_duty, savings: savings}
      else
        {calculated_invoice_value: calculated_invoice_value, calculated_duty: row[:duty_rate], savings: 0}
      end
    end

    def spi_suspended?
      gsp_code = DutySavingsType::SPI_MAP.invert["GSP"]
      row[:spi] == gsp_code && row[:release_date] >= Date.new(2018,1,1) && row[:release_date] <= Date.new(2018,4,30)
    end
    
    # If #calculate_epd, #calculate_trade_discount, or the Ann portion of #calculate_air_sea_differential changes
    # ActualEntryTotalCalculator#combine_ann_savings will also need to change

    def calculate_air_sea_differential
      if row.ann?
        calculated_invoice_value = !row.special_tariff? ? row[:price_before_discounts] : BigDecimal("0")
        calculated_duty = row[:duty] + row[:air_sea_duty_savings]
        savings = row[:air_sea_duty_savings]
        {calculated_invoice_value: calculated_invoice_value, calculated_duty: calculated_duty, savings: savings}
      else
        initial_invoice_value = row[:non_dutiable_amount] + row[:cil_entered_value_7501]
        calculated_invoice_value = !row.special_tariff? ? initial_invoice_value : BigDecimal("0")
        calculated_duty = (initial_invoice_value * row[:duty_rate]).round(2)
        savings = calculated_duty - row[:duty_amount]
        {calculated_invoice_value: calculated_invoice_value, calculated_duty: calculated_duty, savings: savings}
      end
    end

    # Ann only
    def calculate_epd
      calculated_invoice_value = !row.special_tariff? ? row[:price_before_discounts] : BigDecimal("0")
      calculated_duty = row[:duty] + row[:epd_duty_savings]
      savings = row[:epd_duty_savings]
      {calculated_invoice_value: calculated_invoice_value, calculated_duty: calculated_duty, savings: savings}
    end

    # Ann only
    def calculate_trade_discount
      calculated_invoice_value = !row.special_tariff? ? row[:price_before_discounts] : BigDecimal("0")
      calculated_duty = row[:duty] + row[:trade_discount_duty_savings]
      savings = row[:trade_discount_duty_savings]
      {calculated_invoice_value: calculated_invoice_value, calculated_duty: calculated_duty, savings: savings}
    end  
  end
  
  class DutySavingsType
    attr_reader :row

    SPI_MAP = {"A" => "GSP", "AU" => "Australia FTA", "BH" => "Bahrain FTA", "CA" => "CA NAFTA", "CL" => "Chile FTA", "CO" => "Columbia", "D" => "AGOA", "E" => "CBI", 
               "IL" => "Israel FTA", "JO" => "Jordan FTA", "KR" => "Korea FTA", "MA" => "Morocco FTA", "MX" => "MX NAFTA", "N" => "Egypt", "OM" => "Oman FTA", "P" => "CAFTA", 
               "P+" => "CAFTA", "PA" => "Panama FTA", "PE" => "Peru FTA", "R" => "CBTPA", "SG" => "Singapore FTA"}

    def initialize row
      @row = row
    end

    def get
      types = []
      types << [:spi, spi_name] if row[:spi].present?
      types << [:air_sea, "Air Sea Differential"] if air_sea_differential?
      types << [:other, "Other"] if other?
      types << [:first_sale, "First Sale"] if row.first_sale?
      types << [:epd, "EPD Discount"] if epd_discount?
      types << [:trade, "Trade Discount"] if trade_discount?
      types << [:line, "Actual Entry Totals"] unless types.empty?
      types
    end

    def spi_name
      spi_code = row[:spi].to_s.upcase
      spi_name = SPI_MAP[spi_code]
      spi_name.blank? ? spi_code : spi_name
    end
    
    def air_sea_differential?
      if row.ann?
        row[:air_sea_discount] > 0
      else
        row[:transport_mode_code].to_s == "40" && row[:non_dutiable_amount] > 0
      end
    end

    def epd_discount?
      row.ann? ? row[:early_payment_discount] > 0 : false
    end

    def trade_discount?
      row.ann? ? row[:trade_discount] > 0 : false
    end

    def other?
      !row.ann? && row[:transport_mode_code].to_s != "40" && row[:non_dutiable_amount].to_f > 0
    end
  end

  class ActualEntryTotalCalculator
    attr_reader :savings_set, :row
    
    def initialize row, savings_set
      @row = row
      @savings_set = savings_set
    end

    def fill_totals
      actual_entry_totals = savings_set.find{ |s| s[:savings_type] == :line}
      if row.ann?
        fill(actual_entry_totals, ann_discounts(row), [:air_sea, :trade, :epd])
      else
        fill(actual_entry_totals, ascena_discounts(row))
      end
      nil
    end

    # Base the total row on a member of the savings_set. Select by highest savings, and if all are zero,
    # select by highest discount.
    def fill actual_entry_totals, discounts, aggregate_fields=[]
      ss = savings_set.reject{ |s| s[:savings_type] == :line }
      substitute_aggregate(ss, discounts, aggregate_fields) if aggregate_fields.present?
      savings_types = ss.map{ |s| s[:savings_type] }

      highest_svgs = ss.max_by{ |s| s[:calculations].try(:[], :savings) || 0 }
      if highest_svgs[:calculations][:savings] > 0
        actual_entry_totals.merge!(calculations: highest_svgs[:calculations])
      else
        highest_dsct_type = discounts.select{ |k,v| savings_types.include? k }.max_by{ |d| d[1] }.first
        invoice_value = ss.find{ |s| s[:savings_type] == highest_dsct_type }[:calculations][:calculated_invoice_value]
        actual_entry_totals.merge!(calculations: {calculated_invoice_value: invoice_value, calculated_duty: 0, savings: 0})
      end
      nil
    end
    
    def substitute_aggregate svgs_set, dsct_set, agg_fields
      # svgs_set is a copy of savings_set that is missing the totals line
      svgs_agg = []; dsct_agg = []
      savings_set.each do |ss|
        if agg_fields.include? ss[:savings_type]
          svgs_val = svgs_set.find { |s| s[:savings_type] == ss[:savings_type] }
          svgs_agg << svgs_set.delete(svgs_val)
          dsct_val = dsct_set.delete ss[:savings_type]
          dsct_agg << dsct_val
        end
      end
      svgs_set << {savings_type: :aggregate, calculations: combine_ann_savings(svgs_agg)}
      dsct_set[:aggregate] = dsct_agg.sum

      nil
    end

    # if Ann discount-calculation methods in DutySavingsCalculator change, this will need to change, too
    def combine_ann_savings set
      return {savings: 0} unless set.present?
      first_set = set.first[:calculations]
      shared_calculated_invoice_value = first_set[:calculated_invoice_value]
      shared_duty = first_set[:calculated_duty] - first_set[:savings]
      combined_savings = set.sum{ |s| s[:calculations][:savings] }
      combined_calculated_duty = shared_duty + combined_savings
      {calculated_invoice_value: shared_calculated_invoice_value, calculated_duty: combined_calculated_duty, savings: combined_savings }
    end

    def ann_discounts row
      {first_sale: row[:first_sale_difference],
       air_sea: row[:air_sea_discount],
       trade: row[:trade_discount],
       epd: row[:early_payment_discount],
       spi: 0}
    end

    def ascena_discounts row
      {first_sale: row[:first_sale_difference],
       air_sea: row[:air_sea_discount],
       other: row[:non_dutiable_amount],
       spi: 0}
    end
  end 

  class FieldFiller
    attr_accessor :ent_field_helper, :inv_field_helper, :tariff_field_helper
    attr_reader :results
    
    def initialize results
      @results = results
    end

    def fill_missing_fields
      load_helpers
      results.each do |row|
        row.official_tariff = official_tariff row
        
        e_id = row[:e_id]
        cil_id =row[:cil_id]
        # Ordering of these assignments important where noted
        row[:first_sale] = inv_field_helper.fields[cil_id][:cil_first_sale] ? "Y" : "N"
        row[:filer] = ent_field_helper.fields[e_id][:ent_entry_filer]
        row[:arrival_port] = ent_field_helper.fields[e_id][:ent_unlading_port_name]
        row[:entry_port] = ent_field_helper.fields[e_id][:ent_entry_port_name]
        row[:quantity] = quantity row
        row[:unit_of_measure] = unit_of_measure row
        row[:original_fob_unit_value] = original_fob_unit_value row, cil_id
        row[:original_fob_entered_value] = original_fob_entered_value row
        row[:first_sale_difference] = first_sale_difference row, cil_id
        row[:line_entered_value] = line_entered_value row
        row[:price_before_discounts] = price_before_discounts row
        row[:first_sale_duty_savings] = first_sale_duty_savings row
        row[:first_sale_margin_percent] = first_sale_margin_percent row, cil_id
        row[:air_sea_discount] = air_sea_discount row
        row[:air_sea_per_unit_savings] = air_sea_per_unit_savings row # uses air_sea_discount
        row[:air_sea_duty_savings] = air_sea_duty_savings row # uses air_sea_discount
        row[:early_payment_discount] = early_payment_discount row
        row[:epd_per_unit_savings] = epd_per_unit_savings row # uses early_payment_discount
        row[:epd_duty_savings] = epd_duty_savings row # uses early_payment_discount
        row[:trade_discount] = trade_discount row
        row[:trade_discount_per_unit_savings] = trade_discount_per_unit_savings row #uses trade_discount
        row[:trade_discount_duty_savings] = trade_discount_duty_savings row # uses trade_discount
        row[:original_duty_rate] = original_duty_rate row
        row[:spi_duty_savings] = spi_duty_savings row, cil_id
        row[:mp_vs_air_sea] = mp_vs_air_sea row # uses first_sale_duty_savings, air_sea_duty_savings
        row[:mp_vs_epd] = mp_vs_epd row # uses first_sale_duty_savings, epd_duty_savings
        row[:mp_vs_trade_discount] = mp_vs_trade_discount row # uses first_sale_duty_savings, trade_discount_duty_savings
        row[:mp_vs_air_sea_epd_trade] = mp_vs_air_sea_epd_trade row # uses first_sale_duty_savings, air_sea_duty_savings, epd_duty_savings, trade_discount_duty_savings
        row[:first_sale_savings] = row[:first_sale_duty_savings]
        row[:air_sea_savings] = air_sea_savings row #uses mp_vs_air_sea
        row[:epd_savings] = epd_savings row # uses mp_vs_epd
        row[:trade_discount_savings] = trade_discount_savings row # uses mp_vs_trade_discount
        row[:applied_discount] = applied_discount row
      end

      nil
    end

    def load_helpers
      @ent_field_helper = EntFieldHelper.create results
      @inv_field_helper = InvFieldHelper.create results
      @tariff_field_helper = TariffFieldHelper.create results
    end

    def trap_null field
      field.nil? ? BigDecimal("0") : field
    end

    def quantity row
      !row.special_tariff? ? row[:quantity_attrib] : BigDecimal("0")
    end

    def unit_of_measure row
      !row.special_tariff? ? row[:unit_of_measure_attrib] : nil
    end

    def original_fob_unit_value row, cil_id
      !row.special_tariff? ? inv_field_helper.fields[cil_id][:cil_contract_amount_unit_price] : BigDecimal("0")
    end

    def original_fob_entered_value row
      !row.special_tariff? && row[:contract_amount] > 0 ? row[:contract_amount] : BigDecimal("0")
    end

    def first_sale_duty_savings row
      row.first_sale? ? ((row[:contract_amount] - row[:cil_entered_value_7501]) * row[:duty_rate]).round(2) : BigDecimal("0")
    end

    def first_sale_difference row, cil_id
      return BigDecimal("0") unless row.first_sale?
      
      if row.ann?
        !row.special_tariff? ? row[:middleman_charge] : BigDecimal("0")
      else
        !row.special_tariff? ? (row[:contract_amount] - row[:cil_entered_value_7501]) : BigDecimal("0")
      end
    end

    def line_entered_value row
      !row.special_tariff? ? row[:cil_entered_value_7501] : BigDecimal("0")
    end

    def price_before_discounts row
      if row.ann?
        !row.special_tariff? ? row[:value] : BigDecimal("0")
      else
        !row.special_tariff? ? (row[:value] + row[:first_sale_difference]) : BigDecimal("0")
      end
    end

    def first_sale_margin_percent row, cil_id
      return BigDecimal("0") unless row.first_sale?
      
      if row.ann?
        (!row.special_tariff? && row.first_sale?) ? (row[:middleman_charge] / row[:contract_amount]).round(2) : BigDecimal("0")
      else
        fs_difference = trap_null(inv_field_helper.fields[cil_id][:cil_first_sale_difference])
        (!row.special_tariff? && fs_difference > 0) ? (fs_difference / row[:contract_amount]).round(2) : BigDecimal("0")
      end
    end

    def air_sea_discount row
      return BigDecimal("0") if row.special_tariff?
      
      if row.ann?
        row[:air_sea_discount_attrib]
      else
        (row[:transport_mode_code] == "40" && row[:non_dutiable_amount] > 0) ? row[:non_dutiable_amount] : BigDecimal("0")
      end
    end

    def air_sea_per_unit_savings row
      quantity = row[:quantity]
      if row.ann? 
        (!row.special_tariff? && quantity != 0) ? (row[:air_sea_discount] / quantity).round(2) : BigDecimal("0")
      else 
        non_dutiable_amount = row[:non_dutiable_amount]
        if !row.special_tariff? && row[:transport_mode_code] == "40" && non_dutiable_amount > 0 && quantity != 0
          (non_dutiable_amount / quantity).round(2)
        else
          BigDecimal("0")
        end
      end
    end

    def air_sea_duty_savings row
      duty_rate = row[:duty_rate]
      if row.ann?
        (row[:air_sea_discount] * duty_rate).round(2)
      else
        non_dutiable_amount = row[:non_dutiable_amount]
        (row[:transport_mode_code] == "40" && non_dutiable_amount > 0) ? (non_dutiable_amount * duty_rate).round(2) : BigDecimal("0")
      end
    end

    def early_payment_discount row
      row.ann? && !row.special_tariff? ? row[:early_payment_discount_attrib] : BigDecimal("0")
    end

    def epd_per_unit_savings row
      row.ann? && !row.special_tariff? ? (row[:early_payment_discount] / row[:quantity]).round(2) : BigDecimal("0")
    end

    def epd_duty_savings row
      row.ann? && !row.special_tariff? ? (row[:early_payment_discount] * row[:duty_rate]).round(2) : BigDecimal("0")
    end

    def trade_discount row
      row.ann? && !row.special_tariff? ? row[:trade_discount_attrib] : BigDecimal("0")
    end

    def trade_discount_per_unit_savings row
      return 0 if row[:quantity].zero?
      row.ann? && !row.special_tariff? ? (row[:trade_discount] / row[:quantity]).round(2) : BigDecimal("0")
    end

    def trade_discount_duty_savings row
      row.ann? && !row.special_tariff? ? (row[:trade_discount] * row[:duty_rate]).round(2) : BigDecimal("0")
    end

    def original_duty_rate row
      ot = row.official_tariff
      ot ? ot.common_rate : "No HTS Found"
    end

    def spi_duty_savings row, cil_id
      ot = row.official_tariff
      if row[:spi].present? && ot && !row.special_tariff?
        common_rate = guess_common_rate_decimal(ot)
        if common_rate > 0
          return (row[:price_before_discounts] * trap_null(common_rate) - trap_null(inv_field_helper.fields[cil_id][:cil_total_duty])).round(2)
        end
      end
      BigDecimal("0")
    end

    def mp_vs_air_sea row
      !row.special_tariff? ? row[:first_sale_duty_savings] - row[:air_sea_duty_savings] : BigDecimal("0")
    end

    #  OfficialTariff#set_common_rate fails to set common_rate_decimal for any common_rate that includes more than a percentage
    #  This will handle anything that contains a percentage
    def guess_common_rate_decimal ot      
      return ot.common_rate_decimal if ot.common_rate_decimal.present?
      percent = ot.common_rate.to_s.strip.match(/\d+\.?\d*%/).try :[], 0
      percent ? BigDecimal(percent.gsub(/%/, ''), 4)/100 : BigDecimal("0")
    end

    def mp_vs_epd row
      (row.ann? && !row.special_tariff?) ? (row[:first_sale_duty_savings] - row[:epd_duty_savings]) : BigDecimal("0")
    end

    def mp_vs_trade_discount row
      (row.ann? && !row.special_tariff?) ? row[:first_sale_duty_savings] - row[:trade_discount_duty_savings] : BigDecimal("0")
    end

    def mp_vs_air_sea_epd_trade row
      if !row.special_tariff? 
        row[:first_sale_duty_savings] - (row[:air_sea_duty_savings] + row[:epd_duty_savings] + row[:trade_discount_duty_savings])
      else
        BigDecimal("0")
      end
    end

    def air_sea_savings row
      row[:mp_vs_air_sea] < 0 ? row[:mp_vs_air_sea].abs : BigDecimal("0")
    end

    def epd_savings row
      row[:mp_vs_epd] < 0 ? row[:mp_vs_epd].abs : BigDecimal("0")
    end

    def trade_discount_savings row
      row[:mp_vs_trade_discount] < 0 ? row[:mp_vs_trade_discount].abs : BigDecimal("0")
    end

    def applied_discount row
      discount = []
      non_dutiable_amount = row[:non_dutiable_amount]
      contract_amount = row[:contract_amount]
      if row.ann?
        discount << "FS" if  contract_amount != 0 && non_dutiable_amount > 0
        discount << "AS" if contract_amount.zero? && non_dutiable_amount > 0
        discount << "EP" if row[:miscellaneous_discount] > 0
        discount << "TD" if row.other_amount > 0
      else
        discount << "FS" if contract_amount > 0
        discount << "AS" if row[:transport_mode_code] == "40" && non_dutiable_amount > 0
      end
      discount.join(", ")
    end

    def official_tariff row
      imp_ctry_id = row[:import_country_id]
      hts = row[:hts_code]
      tariff_field_helper.tariffs[[imp_ctry_id, hts]]
    end
    
    class EntFieldHelper
      attr_reader :fields

      def self.create results       
        instance = self.new
        e_ids = results.map{ |r| r[:e_id] }.compact.uniq
        instance.load_fields e_ids
        instance
      end

      def initialize flds=nil
        @fields = flds
      end

      def load_fields e_ids
        @fields = Entry.where(id: e_ids)
                       .map{ |e| [e.id, {ent_entry_filer: mfs[:ent_entry_filer].process_export(e, nil),
                                         ent_unlading_port_name: mfs[:ent_unlading_port_name].process_export(e, nil),
                                         ent_entry_port_name: mfs[:ent_entry_port_name].process_export(e, nil)}] }.to_h
      end

      def mfs
        @mfs ||= { ent_entry_filer: ModelField.find_by_uid(:ent_entry_filer), 
                   ent_unlading_port_name: ModelField.find_by_uid(:ent_unlading_port_name), 
                   ent_entry_port_name: ModelField.find_by_uid(:ent_entry_port_name) }
      end
    end
    
    class InvFieldHelper
      attr_reader :fields

      def self.create results
        instance = self.new
        cil_ids = results.map{ |r| r[:cil_id] }.compact.uniq
        instance.load_fields cil_ids
        instance
      end

      def initialize flds=nil
        @fields = flds
      end

      def load_fields cil_ids
        @fields = CommercialInvoiceLine.where(id: cil_ids)
                                       .map{ |cil| [cil.id, { cil_first_sale: mfs[:cil_first_sale].process_export(cil, nil),
                                                              cil_contract_amount_unit_price: trap_nil(mfs[:cil_contract_amount_unit_price].process_export(cil, nil)),
                                                              cil_total_duty: trap_nil(mfs[:cil_total_duty].process_export(cil, nil)),
                                                              cil_first_sale_difference: trap_nil(mfs[:cil_first_sale_difference].process_export(cil, nil)) }] }.to_h
      end

      def mfs
        @mfs ||= { cil_first_sale: ModelField.find_by_uid(:cil_first_sale), cil_contract_amount_unit_price: ModelField.find_by_uid(:cil_contract_amount_unit_price), 
                   cil_total_duty: ModelField.find_by_uid(:cil_total_duty), cil_first_sale_difference: ModelField.find_by_uid(:cil_first_sale_difference ) }
      end

      def trap_nil field
        field.nil? ? BigDecimal("0") : field
      end
    end
    
    class TariffFieldHelper
      attr_reader :tariffs

      def self.create results
        instance = self.new
        hts_codes, imp_ctry_ids = ids(results)       
        instance.load hts_codes, imp_ctry_ids
        instance
      end

      def initialize trffs=nil
        @tariffs = trffs
      end

      def self.ids results
        hts_codes = []; imp_ctry_ids = []
        results.each do |r|
          hts_codes << r[:hts_code]
          imp_ctry_ids << r[:import_country_id]
        end
        [hts_codes, imp_ctry_ids]
      end

      def load hts_codes, imp_ctry_ids
        hts_by_ctry = Hash.new{ |h,k| h[k] = Set.new }
        imp_ctry_ids.zip(hts_codes).each { |pair| hts_by_ctry[pair[0]].add pair[1] }
        @tariffs = {}
        hts_by_ctry.keys.each do |ctry_id| 
          OfficialTariff.where(country_id: ctry_id, hts_code: hts_by_ctry[ctry_id].to_a).each do |ot|
            @tariffs[[ctry_id, ot.hts_code]] = ot
          end
        end
      end
    end
  end

  class Query
    include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
    include OpenChain::Report::ReportHelper

    ASCENA_CUST_NUM = HELPER_PREFIX::ASCENA_CUST_NUM
    ANN_CUST_NUM = HELPER_PREFIX::ANN_CUST_NUM
    MAURICES_CUST_NUM = HELPER_PREFIX::MAURICES_CUST_NUM

    def run cust_numbers, start_date, end_date
      # performance issues require one query per importer
      results = cust_numbers.flat_map{ |cnum| unpack_mysql2(run_query cnum, start_date, end_date) }
      FieldFiller.new(results).fill_missing_fields
      results
    end

    def run_query cust_number, start_date, end_date
      ActiveRecord::Base::connection.execute query(cust_number, start_date, end_date)
    end

    def unpack_mysql2 result
      out = []
      result.each { |r| out << Wrapper.new(r) }
      out
    end

    def query cust_number, start_date, end_date
      # blank fields are all calculated separately, except where noted
      qry = <<-SQL
              SELECT e.broker_reference,
                     e.customer_name,
                     "" AS "First Sale",
                     IF(e.customer_number = "#{ANN_CUST_NUM}" AND o.id IS NULL, inv_vendors.name, ord_vendors.name),
                     IF(e.customer_number = "#{ANN_CUST_NUM}" AND o.id IS NULL, inv_factories.name, ord_factories.name),
                     IF(cil.related_parties, "Y", "N"),
                     e.transport_mode_code,
                     e.fiscal_month,
                     e.release_date,
                     "" AS "Filer",
                     e.entry_number,
                     cil.customs_line_number,
                     ci.invoice_number,
                     cil.part_number,
                     cil.po_number,
                     cil.product_line,
                     IF(e.customer_number = "#{ANN_CUST_NUM}", "NONAGS", ord_type.string_value) AS "Order Type",
                     cil.country_origin_code,
                     cil.country_export_code,
                     e.arrival_date,
                     e.import_date,
                     "" AS "Arrival Port",
                     "" AS "Entry Port",
                     cit.hts_code,
                     IFNULL(cit.duty_rate, 0),
                     IF(e.customer_number = "#{ANN_CUST_NUM}", il.part_description, cit.tariff_description) AS "Goods Description",
                     cil.unit_price,
                     "" AS "Invoice Quantity",
                     "" AS "Invoice UOM",
                     "" AS "Original FOB Unit Value",
                     "" AS "Original FOB Entered Value",
                     cit.duty_amount AS "Duty",
                     "" AS "First Sale Difference",
                     "" AS "First Sale Duty Savings",
                     "" AS "First Sale Margin %",
                     "" AS "Price Before Discounts",
                     "" AS "Line Entered Value",
                     "" AS "Air/Sea Discount",
                     "" AS "Air/Sea Per Unit Savings",
                     "" AS "Air/Sea Duty Savings",
                     "" AS "Early Payment Discount",
                     "" AS "EPD Per Unit Savings",
                     "" AS "EPD Duty Savings",
                     "" AS "Trade Discount",
                     "" AS "Trade Discount per Unit Savings",
                     "" AS "Trade Discount Duty Savings",
                     cit.spi_primary,
                     "" AS "Original Duty Rate",
                     "" AS "SPI Duty Savings",
                     IF(e.fish_and_wildlife_transmitted_date IS NOT NULL, "Y", "N") AS "Fish and Wildlife",
                     0 AS "Hanger Duty Savings", # currently not used
                     "" AS "MP vs Air/Sea",
                     "" AS "MP vs EPD",
                     "" AS "MP vs Trade Discount",
                     "" AS "MP vs Air/Sea/EPD Trade",
                     "" AS "First Sale Savings",
                     "" AS "Air/Sea Savings",
                     "" AS "EPD Savings",
                     "" AS "Trade Discount Savings",
                     "" AS "Applied Discount",
                     # following are for calculations, not display
                     e.id,
                     e.import_country_id,
                     e.customer_number,
                     cil.id,
                     IFNULL(cil.contract_amount, 0),
                     IFNULL(cil.non_dutiable_amount, 0),
                     IFNULL(cil.value, 0),
                     IFNULL(cil.quantity, 0) AS "quantity_attrib",
                     cil.unit_of_measure AS "unit_of_measure_attrib",
                     IFNULL(cil.entered_value_7501, 0),
                     IFNULL(cil.miscellaneous_discount, 0),
                     IFNULL(cil.other_amount, 0),
                     IFNULL(cit.duty_amount, 0),
                     cit.special_tariff,
                     IFNULL(il.air_sea_discount, 0) AS "air_sea_discount_attrib",
                     IFNULL(il.middleman_charge, 0),
                     IFNULL(il.early_pay_discount, 0) AS "early_payment_discount_attrib",
                     IFNULL(il.trade_discount, 0) AS "trade_discount_attrib,"
              FROM entries e
              INNER JOIN commercial_invoices ci on e.id = ci.entry_id
              INNER JOIN commercial_invoice_lines cil on ci.id = cil.commercial_invoice_id
              INNER JOIN commercial_invoice_tariffs cit on cit.commercial_invoice_line_id = cil.id
              LEFT OUTER JOIN invoices i ON i.invoice_number = ci.invoice_number AND i.importer_id = e.importer_id
              LEFT OUTER JOIN invoice_lines il ON i.id = il.invoice_id AND il.part_number = cil.part_number AND il.po_number = cil.po_number
              LEFT OUTER JOIN companies inv_vendors ON inv_vendors.id = i.vendor_id
              LEFT OUTER JOIN companies inv_factories ON inv_factories.id = i.factory_id
              LEFT OUTER JOIN orders o ON o.order_number = CASE ?
                                                             WHEN "#{ASCENA_CUST_NUM}" THEN CONCAT('ASCENA-', cil.product_line, '-', cil.po_number)
                                                             WHEN "#{MAURICES_CUST_NUM}" THEN CONCAT('ASCENA-MAU-', cil.po_number)
                                                             WHEN "#{ANN_CUST_NUM}" THEN CONCAT('ATAYLOR-', cil.po_number)
                                                           END
              LEFT OUTER JOIN companies ord_vendors ON ord_vendors.id = o.vendor_id
              LEFT OUTER JOIN companies ord_factories ON ord_factories.id = o.factory_id
              LEFT OUTER JOIN custom_values ord_type ON ord_type.customizable_id = o.id AND ord_type.customizable_type = "Order" AND ord_type.custom_definition_id = ?
              WHERE e.customer_number = ? AND e.source_system = 'Alliance' AND e.fiscal_date >= ? and e.fiscal_date < ?
              ORDER BY e.customer_number, e.broker_reference
            SQL
      ActiveRecord::Base.sanitize_sql_array([qry, cust_number, cdefs[:ord_type].id, cust_number, start_date, end_date])
    end

    def cdefs 
      @cdefs ||= self.class.prep_custom_definitions [:ord_type]
    end
  end

end; end; end; end
