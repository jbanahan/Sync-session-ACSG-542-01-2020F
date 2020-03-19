require 'open_chain/report/report_helper'
module OpenChain; module Report; class HmStatisticsReport
  include OpenChain::Report::ReportHelper

  class HmDataHolder
    attr_accessor :air_order, :ocean_order, :total_order, :air_unit, :ocean_unit, :total_unit

    def initialize
      self.total_order = 0
      self.air_order = 0
      self.ocean_order = 0
      self.total_unit = 0
      self.air_unit = 0
      self.ocean_unit = 0
    end
  end

  def self.permission? user
    MasterSetup.get.custom_feature?("WWW VFI Track Reports") && (user.view_entries? && (user.company.master? || user.company.customs_identifier == 'HENNE'))
  end

  def self.run_report run_by, settings={}
    self.new.run run_by, settings
  end

  def run run_by, settings
    start_date = sanitize_date_string settings['start_date'], run_by.time_zone
    end_date = sanitize_date_string settings['end_date'], run_by.time_zone
    wb = XlsMaker.new_workbook
    
    add_summary_sheet wb, start_date, end_date
    add_ocean_sheet(wb, start_date, end_date, run_by.time_zone)
    add_air_sheet(wb, start_date, end_date, run_by.time_zone)
    
    workbook_to_tempfile wb, 'HmStatisticsReport-'
  end

  def conversions(time_zone)
    {"Release Date" => datetime_translation_lambda(time_zone)}
  end

  def add_ocean_sheet wb, start_date, end_date, time_zone
    XlsMaker.create_sheet wb, "Ocean"
    table_from_query wb.worksheets.last, raw_ocean_query(start_date, end_date), conversions(time_zone)
  end

  def add_air_sheet wb, start_date, end_date, time_zone
    XlsMaker.create_sheet wb, "Air"
    table_from_query wb.worksheets.last, raw_air_query(start_date, end_date), conversions(time_zone)
  end

  def add_summary_sheet wb, start_date, end_date
    sheet = XlsMaker.create_sheet wb, "Statistics"
    
    mh = Hash.new
    load_order_data mh, start_date, end_date
    load_air_tu_data mh, start_date, end_date
    load_ocean_tu_data mh, start_date, end_date

    XlsMaker.add_body_row sheet, 0, [nil,"Order",nil,nil,nil,"Transport Units"]
    XlsMaker.add_body_row sheet, 1, ["Export Country","AIR","OCEAN","Total Orders",nil,"AIR","OCEAN","Total TU"]

    cursor = 2
    mh.keys.sort.each do |country|
      dh = mh[country]
      XlsMaker.add_body_row sheet, cursor, [country,dh.air_order,dh.ocean_order,dh.total_order,"",dh.air_unit,dh.ocean_unit,dh.total_unit]
      cursor += 1
    end

    vals = mh.values

    XlsMaker.add_body_row sheet, cursor, [
      "Total Result", 
      vals.inject(0) {|mem, v| mem + v.air_order},
      vals.inject(0) {|mem, v| mem + v.ocean_order},
      vals.inject(0) {|mem, v| mem + v.total_order},
      "",
      vals.inject(0) {|mem, v| mem + v.air_unit},
      vals.inject(0) {|mem, v| mem + v.ocean_unit},
      vals.inject(0) {|mem, v| mem + v.total_unit},
    ]

    cursor += 2

    execute_query(totals_query(start_date, end_date)) do |result_set|
      totals = result_set.first
      XlsMaker.add_body_row sheet, cursor, ["Total Duty",totals[1]]
      cursor += 1
      XlsMaker.add_body_row sheet, cursor, ["Total Entered Value",totals[0]]
    end
  end

  def totals_query start_date, end_date
    <<-SQL
      SELECT SUM(IFNULL(t.entered_value, 0)) AS entered_value, 
             SUM(IFNULL(t.duty_amount, 0) + IFNULL(l.hmf, 0) + IFNULL(l.prorated_mpf, 0) + IFNULL(l.cotton_fee, 0))
      FROM entries e
          INNER JOIN commercial_invoices i ON e.id = i.entry_id
          INNER JOIN commercial_invoice_lines l ON l.commercial_invoice_id = i.id
          INNER JOIN commercial_invoice_tariffs t ON t.commercial_invoice_line_id = l.id
      WHERE e.customer_number = 'HENNE'
          AND (e.release_date >= '#{start_date}' AND e.release_date < '#{end_date}')
          AND (LENGTH(i.invoice_number) IN (6,7) OR INSTR(i.invoice_number, '-') IN (7,8))
    SQL
  end
  
  def load_order_data master_hash, start_date, end_date
    execute_query(orders_query(start_date, end_date)) do |result_set|
      load_order_dh result_set, master_hash
    end
  end

  def load_order_dh result_set, master_hash
    result_set.each do |row|
      dh = data_holder master_hash, row[0]
      case row[1]
      when 'AIR'
        dh.air_order = row[2]
        dh.total_order += row[2]
      when 'OCEAN'
        dh.ocean_order = row[2]
        dh.total_order += row[2]
      end
    end       
  end

  def orders_query start_date, end_date
    <<-SQL
      SELECT IF(export_country_codes LIKE '%DE%', 'DE', export_country_codes) AS 'ecc',
        (CASE e.transport_mode_code 
          WHEN 40 THEN "AIR" 
          WHEN 41 THEN "AIR" 
          WHEN 10 THEN "OCEAN"
          WHEN 11 THEN "OCEAN" 
          ELSE "OTHER" 
         END) AS 'Mode', 
        COUNT(*) AS 'orders'
      FROM entries e
        INNER JOIN commercial_invoices ci ON ci.entry_id = e.id 
          AND (LENGTH(ci.invoice_number) IN (6,7) OR INSTR(ci.invoice_number, '-') IN (7,8))
      WHERE e.customer_number = 'HENNE'
        AND (e.release_date >= '#{start_date}' AND e.release_date < '#{end_date}')
      GROUP BY mode, ecc
    SQL
  end

  def load_ocean_tu_data master_hash, start_date, end_date
    execute_query(ocean_tu_query(start_date, end_date)) do |result_set|
      load_ocean_tu_dh result_set, master_hash
    end
  end

  def load_ocean_tu_dh result_set, master_hash
    result_set.each do |row|
      dh = data_holder master_hash, row[0]
      dh.ocean_unit = row[1]
      dh.total_unit += dh.ocean_unit
    end
  end

  def ocean_tu_query start_date, end_date
    <<-SQL
      SELECT IF(export_country_codes LIKE '%DE%', 'DE', export_country_codes) AS 'ecc', 
        COUNT(DISTINCT c.container_number)
      FROM entries e
        INNER JOIN commercial_invoices ci ON e.id = ci.entry_id
        INNER JOIN containers c ON e.id = c.entry_id
      WHERE e.customer_number = 'HENNE'
        AND e.transport_mode_code IN (10, 11)
        AND (LENGTH(ci.invoice_number) IN (6,7) OR INSTR(ci.invoice_number, '-') IN (7,8))
        AND (e.release_date >= '#{start_date}' AND e.release_date < '#{end_date}')
      GROUP BY ecc
    SQL
  end

  def load_air_tu_data master_hash, start_date, end_date
    execute_query(raw_air_query(start_date, end_date)) do |result_set|
      load_air_tu_dh result_set, master_hash
    end
  end

  def load_air_tu_dh result_set, master_hash
    bills = Hash.new do |hash, key| 
      hash[key] = Hash.new{ |h, k| h[k] = [] }
    end
    result_set.each do |row| 
      if row[1].blank? 
        bills[row[0]][:master].concat(row[2].try(:split, "\n ") || []) 
      else 
        bills[row[0]][:house].concat(row[1].try(:split, "\n ") || [])
      end
    end
    bills.each do |ctry, blz| 
      dh = data_holder master_hash, ctry
      dh.air_unit = blz[:master].uniq.count + blz[:house].uniq.count
      dh.total_unit += dh.air_unit
    end
  end

  def raw_ocean_query start_date, end_date
    <<-SQL
     SELECT IF(export_country_codes LIKE '%DE%', 'DE', export_country_codes) AS 'Export Country Codes', 
            e.transport_mode_code "Transport Mode Code", 
            e.release_date "Release Date", 
            ci.invoice_number "Invoice No.", 
            c.container_number "Container No.", 
            e.entry_number "Entry No."
     FROM entries e
       INNER JOIN commercial_invoices ci ON e.id = ci.entry_id
       INNER JOIN containers c ON e.id = c.entry_id
     WHERE e.customer_number = 'HENNE'
       AND e.transport_mode_code IN (10, 11)
       AND (LENGTH(ci.invoice_number) IN (6,7) OR INSTR(ci.invoice_number, '-') IN (7,8))
       AND (e.release_date >= '#{start_date}' AND e.release_date < '#{end_date}')
    SQL
  end

  def raw_air_query start_date, end_date
    <<-SQL
      SELECT IF(export_country_codes LIKE '%DE%', 'DE', export_country_codes) AS 'Export Country Codes', 
             e.house_bills_of_lading "House Bills", 
             e.master_bills_of_lading "Master Bills", 
             e.transport_mode_code "Transport Mode Code", 
             e.release_date "Release Date", 
             ci.invoice_number "Invoice No.", 
             e.entry_number "Entry No."
      FROM entries e
        INNER JOIN commercial_invoices ci ON e.id = ci.entry_id
      WHERE e.customer_number = 'HENNE'
        AND e.transport_mode_code IN (40, 41)
        AND (LENGTH(ci.invoice_number) IN (6,7) OR INSTR(ci.invoice_number, '-') IN (7,8))
        AND (e.release_date >= '#{start_date}' AND e.release_date < '#{end_date}')
    SQL
  end

  def data_holder master_hash, country_code
    master_hash[country_code] ||= HmDataHolder.new
  end
end; end; end
