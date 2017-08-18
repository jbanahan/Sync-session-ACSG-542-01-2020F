require 'open_chain/report/report_helper'
require 'open_chain/custom_handler/ascena/ascena_report_helper'
require 'open_chain/fiscal_calendar_scheduling_support'

module OpenChain; module Report; class AscenaActualVsPotentialFirstSaleReport
  extend OpenChain::FiscalCalendarSchedulingSupport
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include OpenChain::Report::ReportHelper

  SYSTEM_CODE = "ASCENA"

  def self.permission? user
    importer = ascena
    return false unless importer

    (MasterSetup.get.system_code == "www-vfitrack-net" || Rails.env.development?) && 
    (user.view_entries? && (user.company.master? || importer.can_view?(user)))
  end

  def self.ascena
    Company.where(system_code: SYSTEM_CODE).first
  end

  def self.run_schedulable settings={}
    run_if_configured(settings) do |fiscal_month, fiscal_date|
      self.new.send_email(settings['email'])
    end
  end

  def self.run_report run_by, settings = {}
    self.new.run run_by, settings
  end

  def run run_by, settings
    wb = WorkbookGenerator.create_workbook run_by.time_zone, cdefs, eligible_mids
    workbook_to_tempfile wb, 'ActualVsPotentialFirstSale-', file_name: "Actual vs Potential First Sale.xls"
  end

  def send_email email
    wb = WorkbookGenerator.create_workbook "Eastern Time (US & Canada)", cdefs, eligible_mids
    workbook_to_tempfile wb, 'ActualVsPotentialFirstSale-', file_name: "Actual vs Potential First Sale.xls" do |t|
      subject = "Actual vs Potential First Sale Report"
      body = "<p>Report attached.<br>--This is an automated message, please do not reply.<br>This message was generated from VFI Track</p>".html_safe
      OpenMailer.send_simple_html(email, subject, body, t).deliver!
    end
  end
  
  def eligible_mids
    DataCrossReference.where(cross_reference_type: 'asce_mid').pluck(:key).map{ |k| k.split("-").first }
  end
  
  def cdefs
    self.class.prep_custom_definitions [:ord_type, :ord_selling_agent, :ord_line_wholesale_unit_price, :prod_vendor_style, :prod_reference_number]
  end

  class WorkbookGenerator
    extend OpenChain::Report::ReportHelper
    def self.create_workbook time_zone, cdefs, eligible_mids
      wb, sheet_1, sheet_2, sheet_3, sheet_4 = create_empty_workbook
      fmr = FiscalMonthRange.new
      query_results = SavingsQueryRunner.run_savings_queries cdefs, fmr
      first_sale_hash, missed_hash, potential_hash, avg_savings_percentages = QueryConverter.assemble_summaries query_results, eligible_mids
      write_summary_sheet(sheet_1, first_sale_hash, missed_hash, potential_hash, avg_savings_percentages)
      detail_queries = DetailQueryGenerator.get_detail_queries cdefs, eligible_mids, fmr
      write_detail_sheets(time_zone, detail_queries, sheet_2, sheet_3, sheet_4)
      wb
    end

    # PRIVATE

    def self.write_detail_sheets time_zone, detail_queries, sheet_2, sheet_3, sheet_4
      table_from_query sheet_2, detail_queries[:first_sale], conversions(time_zone)
      table_from_query sheet_3, detail_queries[:missed], conversions(time_zone)
      table_from_query sheet_4, detail_queries[:potential], conversions(time_zone)
    end 

    def self.conversions time_zone
      {"Entry Filed Date" => datetime_translation_lambda(time_zone)}
    end

    def self.create_empty_workbook
      wb, sheet_1 = XlsMaker.create_workbook_and_sheet "First Sale Report"
      sheet_2 = XlsMaker.create_sheet wb, "Savings Detail"
      sheet_3 = XlsMaker.create_sheet wb, "Missed Savings Detail"
      sheet_4 = XlsMaker.create_sheet wb, "Potential Savings Detail"
      [wb, sheet_1, sheet_2, sheet_3, sheet_4]
    end

    def self.write_summary_sheet sheet, first_sale_hsh, missed_hsh, potential_hsh, avg_savings_percentages
      cursor = 0
      XlsMaker.add_body_row sheet, cursor += 1, ["First Sale Eligible Vendors Claiming First Sale at Entry"]
      XlsMaker.add_body_row sheet, cursor += 1, ['Vendor', 'Seller', 'Factory', 'Previous Fiscal Month Duty Savings', 'Fiscal Season to Date Savings', 'Fiscal YTD Savings']
      cursor = write_section sheet, first_sale_hsh, cursor += 1
      
      XlsMaker.add_body_row sheet, cursor += 1, ['First Sale Eligible Vendors Not Claiming First Sale at Entry']
      cursor = write_vendor_margins sheet, avg_savings_percentages, cursor += 1
      XlsMaker.add_body_row sheet, cursor += 1, ['Vendor', 'Seller', 'Factory', 'Previous Fiscal Month Missed Duty Savings', 'Fiscal Season to Date Missed Savings', 'Fiscal YTD Missed Savings']
      cursor = write_section sheet, missed_hsh, cursor += 1
      
      XlsMaker.add_body_row sheet, cursor += 1, ['First Sale Ineligible Vendors Potential Duty Savings']
      cursor = write_vendor_margins sheet, avg_savings_percentages, cursor += 1
      XlsMaker.add_body_row sheet, cursor += 1, ['Vendor', 'Seller', 'Factory', 'Previous Fiscal Month Potential Duty Savings', 'Fiscal Season to Date Potential Savings', 'Fiscal YTD Potential Savings']
      cursor = write_section sheet, potential_hsh, cursor += 1
    end

    def self.write_section sheet, hsh, cursor
      hsh[:triplets].each do |vendor, seller_factory_pairs|
        seller_factory_pairs.each do |sf|
          seller, factory = sf
          XlsMaker.add_body_row sheet, cursor, [vendor, seller, factory, hsh[:previous_fiscal_month][:lines][vendor][seller][factory], 
                                                                         hsh[:fiscal_season_to_date][:lines][vendor][seller][factory], 
                                                                         hsh[:fiscal_ytd][:lines][vendor][seller][factory]]
          cursor += 1                                                                         
        end
        XlsMaker.add_body_row sheet, cursor, [nil, nil, nil, hsh[:previous_fiscal_month][:vendor_total][vendor],
                                                             hsh[:fiscal_season_to_date][:vendor_total][vendor],
                                                             hsh[:fiscal_ytd][:vendor_total][vendor], 
                                                             "#{vendor} Subtotal"]
        cursor += 1
      end
      cursor += 1
      XlsMaker.add_body_row sheet, cursor, [nil, nil, nil, hsh[:previous_fiscal_month][:grand_total],
                                                           hsh[:fiscal_season_to_date][:grand_total],
                                                           hsh[:fiscal_ytd][:grand_total], "Total"]
      cursor += 1
    end

    def self.write_vendor_margins sheet, avg_savings_percentages, cursor
      XlsMaker.add_body_row sheet, cursor, [nil, (avg_savings_percentages[:previous_fiscal_month] * 100).round(2).to_s + '%', 'Previous Fiscal Period Average Vendor Margin']
      XlsMaker.add_body_row sheet, cursor += 1, [nil, (avg_savings_percentages[:fiscal_season_to_date] * 100).round(2).to_s + '%', 'Fiscal Season Average Vendor Margin']
      XlsMaker.add_body_row sheet, cursor += 1, [nil, (avg_savings_percentages[:fiscal_ytd] * 100).round(2).to_s + '%', 'Fiscal YTD Average Vendor Margin']
      cursor += 1
    end
  end

  class QueryConverter
    def self.assemble_summaries query_results, eligible_mids
      eligible_results, potential_results = split_results(query_results) { |rs| mid_partition rs, eligible_mids }
      first_sale_results, missed_results = split_results(eligible_results) { |rs| first_sale_partition rs }
      first_sale_hash = convert_first_sale_results(first_sale_results)
      avg_savings_percentages = extract_avg_savings first_sale_hash
      missed_hash = convert_missed_or_potential_results(missed_results, avg_savings_percentages)
      potential_hash = convert_missed_or_potential_results(potential_results, avg_savings_percentages)
      [first_sale_hash, missed_hash, potential_hash, avg_savings_percentages]
    end

    #PRIVATE
    
    def self.split_results query_results
      month_first_half, month_second_half = yield(query_results[:previous_fiscal_month])
      season_first_half, season_second_half = yield(query_results[:fiscal_season_to_date])
      ytd_first_half, ytd_second_half = yield(query_results[:fiscal_ytd])
      [{previous_fiscal_month: month_first_half, fiscal_season_to_date: season_first_half, fiscal_ytd: ytd_first_half}, 
       {previous_fiscal_month: month_second_half, fiscal_season_to_date: season_second_half, fiscal_ytd: ytd_second_half}]
    end

    def self.mid_partition query_results, eligible_mids
      query_results.partition{ |r| eligible_mids.include? r['mid'] }
    end

    def self.first_sale_partition query_results
      query_results.partition{ |r| r['first_sale_flag'] == 'Y' }
    end

    def self.extract_avg_savings first_sale_hash
      {previous_fiscal_month: first_sale_hash[:previous_fiscal_month][:avg_savings_perc], 
       fiscal_season_to_date: first_sale_hash[:fiscal_season_to_date][:avg_savings_perc], 
       fiscal_ytd: first_sale_hash[:fiscal_season_to_date][:avg_savings_perc]}
    end

    def self.convert_first_sale_results query_results
      prev_month = convert_one_first_sale_result(query_results[:previous_fiscal_month])
      season = convert_one_first_sale_result(query_results[:fiscal_season_to_date])
      ytd = convert_one_first_sale_result(query_results[:fiscal_ytd])
      triplets = combine_triplets(prev_month[:triplets], season[:triplets], ytd[:triplets])
      {previous_fiscal_month: prev_month, fiscal_season_to_date: season, fiscal_ytd: ytd, triplets: triplets }
    end

    def self.convert_missed_or_potential_results query_results, avg_savings_percs
      prev_month = convert_one_missed_or_potential_result(query_results[:previous_fiscal_month], avg_savings_percs[:previous_fiscal_month])
      season = convert_one_missed_or_potential_result(query_results[:fiscal_season_to_date], avg_savings_percs[:fiscal_season_to_date])
      ytd = convert_one_missed_or_potential_result(query_results[:fiscal_ytd], avg_savings_percs[:fiscal_ytd])
      triplets = combine_triplets(prev_month[:triplets], season[:triplets], ytd[:triplets])
      {previous_fiscal_month: prev_month, fiscal_season_to_date: season, fiscal_ytd: ytd, triplets: triplets }
    end
    
    def self.convert_one_first_sale_result query_result
      vendor_total = Hash.new{|h,k| h[k] = 0}
      grand_total = first_sale_diff_total = inv_val_contract_total = avg_savings_perc = 0
      triplets = []
      first_sale = init_deep_hash

      query_result.each do |r|
        vendor, seller, factory = triplet_from_result r
        triplets << [vendor, seller, factory] # Must match ORDER BY in savings_query
        first_sale[vendor][seller][factory] = r['first_sale_sav'].round(2)
        vendor_total[vendor] += (r['first_sale_sav']).round(2)
        first_sale_diff_total += (r['first_sale_diff'])
        inv_val_contract_total += (r['inv_val_contract'])
        grand_total += (r['first_sale_sav']).round(2)
        avg_savings_perc = BigDecimal(first_sale_diff_total, 20) / BigDecimal(inv_val_contract_total, 20)
      end
      {lines: first_sale, vendor_total: vendor_total, grand_total: grand_total, avg_savings_perc: avg_savings_perc, triplets: triplets}
    end

    def self.convert_one_missed_or_potential_result query_result, avg_savings_perc
      vendor_total = Hash.new{|h,k| h[k] = 0}
      grand_total = 0
      triplets = []
      missed_or_potential = init_deep_hash

      query_result.each do |r|
        vendor, seller, factory = triplet_from_result r
        triplets << [vendor, seller, factory] # Must match ORDER BY in savings_query
        missed_or_potential[vendor][seller][factory] = (r['val_contract_x_tariff_rate'] * avg_savings_perc).round(2)
        vendor_total[vendor] += (r['val_contract_x_tariff_rate'] * avg_savings_perc).round(2)
        grand_total += (r['val_contract_x_tariff_rate'] * avg_savings_perc).round(2)
      end
      {lines: missed_or_potential, vendor_total: vendor_total, grand_total: grand_total, triplets: triplets}
    end

    def self.triplet_from_result r
      vendor = r['vendor'] || ''
      seller = r['seller'] || ''
      factory = r['factory'] || ''
      [vendor, seller, factory]
    end

    def self.combine_triplets prev_month_triplets, season_triplets, ytd_triplets
      triplets_by_vendor = Hash.new{|h, k| h[k] = []}
      (prev_month_triplets + season_triplets + ytd_triplets).sort.uniq.each { |t| triplets_by_vendor[t[0]] << [t[1], t[2]] }
      triplets_by_vendor
    end

    def self.init_deep_hash
      Hash.new do |h1, k1| 
        h1[k1] = Hash.new do |h2, k2|
          h2[k2] = Hash.new { |h3, k3| h3[k3] = 0 }
        end
      end
    end
  end

  module SharedSql

    def first_sale_difference inv_line_alias
      "IF(contract_amount IS NULL OR contract_amount = 0, 0, ROUND((#{inv_line_alias}.contract_amount - #{inv_line_alias}.value), 2))"
    end

    def first_sale_savings inv_line_alias
      <<-SQL
        IF(contract_amount IS NULL OR contract_amount = 0, 0,
          (SELECT ROUND((l.contract_amount - l.value) * (t.duty_amount / t.entered_value), 2)
           FROM commercial_invoice_lines l
             INNER JOIN commercial_invoice_tariffs t ON l.id = t.commercial_invoice_line_id
           WHERE l.id = #{inv_line_alias}.id
           LIMIT 1 ))
      SQL
    end

  end

  class FiscalMonthRange
    
    def range_for_previous_fiscal_month
      previous_month = current_fm.back 1
      "e.fiscal_date >= '#{previous_month.start_date}' AND e.fiscal_date < '#{current_fm.start_date}'"
    end

    def range_for_fiscal_season_to_date
      months_ago = (1..6).include?(current_fm.month_number) ? 1 : 7
      start_fm = current_fm.back(current_fm.month_number - months_ago)
      "e.fiscal_date >= '#{start_fm.start_date}' AND e.fiscal_date < '#{current_fm.start_date}'"
    end

    def range_for_fiscal_ytd
      start_fm = current_fm.back(current_fm.month_number - 1)
      "e.fiscal_date >= '#{start_fm.start_date}' AND e.fiscal_date < '#{current_fm.start_date}'"
    end
    
    def current_fm
      unless @current_fm
        today = Time.zone.now.in_time_zone("America/New_York").to_date
        ascena = Company.where(system_code: SYSTEM_CODE).first
        @current_fm = FiscalMonth.get(ascena, today)
      end
      @current_fm
    end
  
  end


  class DetailQueryGenerator
    extend OpenChain::CustomHandler::Ascena::AscenaReportHelper
    extend SharedSql
    
    def self.get_detail_queries cdefs, eligible_mids, fm_range
      first_sale = detail_query(cdefs, fm_range, true, "cil.mid IN (#{eligible_mids.map{ |mid| '\'' + mid + '\'' }.join(',')}) AND cil.contract_amount > 0")
      missed = detail_query(cdefs, fm_range, false, "cil.mid IN (#{eligible_mids.map{ |mid| '\'' + mid + '\'' }.join(',')}) AND cil.contract_amount <= 0")
      potential = detail_query(cdefs, fm_range, false, "(cil.mid NOT IN (#{eligible_mids.map{ |mid| '\'' + mid + '\'' }.join(',')}) OR cil.mid IS NULL)")
      {first_sale: first_sale, missed: missed, potential: potential}
    end

    def self.detail_query cdefs, fm_range, show_savings_columns, where_clause
      <<-SQL
        SELECT e.entry_number AS "Entry Number",
               e.entry_filed_date AS "Entry Filed Date",
               e.first_release_date AS "Entry First Release Date",
               e.fiscal_month AS "Fiscal Month",
               IF(ord_type.string_value = "NONAGS", "", ord_agent.string_value) AS 'AGS Office',
               vend.name AS 'Vendor Name',
               fact.name AS 'MID Supplier Name',
               cil.mid AS 'MID',
               #{invoice_value_brand('o', 'cil', cdefs[:ord_line_wholesale_unit_price].id, cdefs[:prod_reference_number].id)} AS 'Invoice Value - Brand',
               cil.country_origin_code AS 'COO',
               (SELECT prod_style.string_value
                FROM order_lines ordln
                  INNER JOIN products prod ON prod.id = ordln.product_id
                  INNER JOIN custom_values prod_style ON prod_style.customizable_id = ordln.product_id AND prod_style.customizable_type = "Product" AND prod_style.custom_definition_id = #{cdefs[:prod_vendor_style].id}
                WHERE ordln.order_id = o.id
                LIMIT 1) AS 'Style Number',
               cil.po_number AS 'PO Number',
               ci.invoice_number AS "Invoice Number",
               cil.quantity AS "Quantity",
               cil.unit_price AS "Unit Price",
               cit.duty_rate AS "Invoice Tariff - Duty Rate",
               cit.duty_amount AS "Invoice Tariff - Duty",
               #{invoice_value_contract('cil')} AS 'Invoice Value - Contract',
               #{unit_price_7501('cil')} AS 'Unit Price - 7501',
               #{invoice_value_7501('cil')} AS 'Invoice Value - 7501',
               #{savings_fields('cil') if show_savings_columns}
               IF(cil.contract_amount > 0, 'Y', 'N') AS 'First Sale Flag'
        FROM entries e
          INNER JOIN commercial_invoices ci ON e.id = ci.entry_id
          INNER JOIN commercial_invoice_lines cil ON ci.id = cil.commercial_invoice_id
          INNER JOIN commercial_invoice_tariffs cit ON cil.id = cit.commercial_invoice_line_id
          LEFT OUTER JOIN orders o ON o.order_number = CONCAT("ASCENA-", cil.po_number)
          LEFT OUTER JOIN companies vend ON vend.id = o.vendor_id
          LEFT OUTER JOIN companies fact ON fact.id = o.factory_id
          LEFT OUTER JOIN custom_values ord_type ON ord_type.customizable_id = o.id AND ord_type.customizable_type = "Order" AND ord_type.custom_definition_id = #{cdefs[:ord_type].id}
          LEFT OUTER JOIN custom_values ord_agent ON ord_agent.customizable_id = o.id AND ord_agent.customizable_type = "Order" AND ord_agent.custom_definition_id = #{cdefs[:ord_selling_agent].id}
        WHERE e.customer_number = 'ASCE' AND #{fm_range.range_for_previous_fiscal_month} AND #{where_clause}
        ORDER BY "Entry Filed Date"
      SQL
    end

    private

    def self.savings_fields commercial_invoice_line_alias
      <<-SQL
        #{first_sale_difference(commercial_invoice_line_alias)} AS 'Value Reduction',
        #{first_sale_difference(commercial_invoice_line_alias)} / #{invoice_value_contract(commercial_invoice_line_alias)} AS 'Vendor Margin',
        #{first_sale_savings(commercial_invoice_line_alias)} AS 'Invoice Line - First Sale Savings',
      SQL
    end

  end


  class SavingsQueryRunner
    extend OpenChain::CustomHandler::Ascena::AscenaReportHelper
    extend SharedSql
    
    def self.run_savings_queries cdefs, fm_range
      prev_month = run_savings_previous_fiscal_month(cdefs, fm_range)
      season = run_savings_fiscal_season_to_date(cdefs, fm_range)
      ytd = run_savings_fiscal_ytd(cdefs, fm_range)
      {previous_fiscal_month: prev_month, fiscal_season_to_date: season, fiscal_ytd: ytd}
    end

    # PRIVATE
    
    def self.run_savings_previous_fiscal_month cdefs, fm_range
      ActiveRecord::Base.connection.exec_query savings_query(cdefs, fm_range.range_for_previous_fiscal_month)
    end

    def self.run_savings_fiscal_season_to_date cdefs, fm_range
      ActiveRecord::Base.connection.exec_query savings_query(cdefs, fm_range.range_for_fiscal_season_to_date)
    end

    def self.run_savings_fiscal_ytd cdefs, fm_range
      ActiveRecord::Base.connection.exec_query savings_query(cdefs, fm_range.range_for_fiscal_ytd)
    end

    def self.savings_query cdefs, where_clause
      <<-SQL
        SELECT vend.name AS vendor,
               cil.mid AS mid,
               ord_agent.string_value AS seller,
               fact.name AS factory,
               IF(cil.contract_amount > 0, 'Y', 'N') AS first_sale_flag,
               SUM(#{first_sale_savings('cil')}) AS first_sale_sav,
               SUM(#{first_sale_difference('cil')}) AS first_sale_diff,
               SUM(#{invoice_value_contract('cil')}) AS inv_val_contract,
               SUM(#{invoice_value_contract('cil')} * (SELECT duty_rate 
                                                       FROM commercial_invoice_tariffs t 
                                                       WHERE t.commercial_invoice_line_id = cil.id 
                                                       LIMIT 1)) AS val_contract_x_tariff_rate
        FROM entries e
          INNER JOIN commercial_invoices ci ON e.id = ci.entry_id
          INNER JOIN commercial_invoice_lines cil ON ci.id = cil.commercial_invoice_id
          INNER JOIN commercial_invoice_tariffs cit ON cil.id = cit.commercial_invoice_line_id
          LEFT OUTER JOIN orders o ON o.order_number = CONCAT("ASCENA-", cil.po_number)
          LEFT OUTER JOIN companies fact ON fact.id = o.factory_id
          LEFT OUTER JOIN custom_values ord_agent ON ord_agent.customizable_id = o.id AND ord_agent.customizable_type = "Order" AND ord_agent.custom_definition_id = #{cdefs[:ord_selling_agent].id}
          LEFT OUTER JOIN companies vend ON vend.id = o.vendor_id
        WHERE e.customer_number = 'ASCE' AND #{where_clause}
        GROUP BY vendor, mid, factory, seller, first_sale_flag
        ORDER BY vendor, seller, factory # Must match triplet order in convert_query
      SQL
    end

  end

 

end; end; end