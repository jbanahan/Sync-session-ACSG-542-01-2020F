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
    user.view_entries? && (user.company.master? || user.company.alliance_customer_number=='HENNE') 
  end

  def self.run_report run_by, settings={}
    self.new.run run_by, settings
  end

  def run run_by, settings
    start_date = sanitize_date_string settings['start_date']
    end_date = sanitize_date_string settings['end_date']

    wb = Spreadsheet::Workbook.new
    sheet = wb.create_worksheet :name=>'Statistics'
    
    mh = Hash.new
    load_order_data mh, start_date, end_date
    load_tu_data mh, start_date, end_date

    XlsMaker.add_body_row sheet, 0, ["","Order","","","","Transport Units"]
    XlsMaker.add_body_row sheet, 1, ["Export Country","AIR","OCEAN","Total Orders","","AIR","OCEAN","Total TU"]

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

    totals = total_values start_date, end_date
    XlsMaker.add_body_row sheet, cursor, ["Total Duty",totals[1]]
    cursor += 1
    XlsMaker.add_body_row sheet, cursor, ["Total Entered Value",totals[0]]

    workbook_to_tempfile wb, 'HmStatisticsReport-'
  end

  private

  def total_values start_date, end_date
    qry = <<QRY
select sum(entries.entered_value), sum(entries.total_duty_direct)
from entries
where entries.customer_number = 'HENNE'
and
arrival_date BETWEEN '#{start_date}' and '#{end_date}'
and
(select avg(length(commercial_invoices.invoice_number)) from commercial_invoices where commercial_invoices.entry_id = entries.id) = 6    
QRY
    ActiveRecord::Base.connection.execute(qry).first
  end
  def load_order_data master_hash, start_date, end_date
     orders_qry = <<QRY
select 
if(export_country_codes like '%DE%', 'DE', export_country_codes) as 'ecc',
(case entries.transport_mode_code when 40 then "AIR" when 11 then "OCEAN" when 30 then 'OCEAN' when 21 then 'OCEAN' else "OTHER" end) as 'Mode', 
count(*) as 'orders'
from entries
inner join commercial_invoices on commercial_invoices.entry_id = entries.id and NOT LENGTH(commercial_invoices.invoice_number) = 8
where entries.customer_number = 'HENNE'
and
arrival_date BETWEEN '#{start_date}' and '#{end_date}'
group by mode, ecc
QRY
    result_set = ActiveRecord::Base.connection.execute orders_qry
    result_set.each do |row|
      dh = data_holder master_hash, row[0]
      case row[1]
      when 'AIR'
        dh.air_order = row[2]
      when 'OCEAN'
        dh.ocean_order = row[2]
      end
      dh.total_order = dh.total_order + row[2]
    end       
  end
  
  def load_tu_data master_hash, start_date, end_date
    transport_units_qry = <<QRY
select ecc, 
mode, 
count(*) as 'Transport Units' from (
select distinct master_bills_of_lading, (case entries.transport_mode_code when 40 then "AIR" when 11 then "OCEAN" when 30 then 'OCEAN' when 21 then 'OCEAN' else "OTHER" end) as 'Mode', 
if(export_country_codes like '%DE%', 'DE', export_country_codes) as 'ecc'
from entries 
where customer_number = 'HENNE'
and 
arrival_date between '#{start_date}' and '#{end_date}'
and
(select count(*) from commercial_invoices where commercial_invoices.entry_id = entries.id and length(commercial_invoices.invoice_number) = 8) = 0 
) x
group by mode, ecc
QRY
    result_set = ActiveRecord::Base.connection.execute transport_units_qry
    result_set.each do |row|
      dh = data_holder master_hash, row[0]
      case row[1]
      when 'AIR'
        dh.air_unit = row[2]
      when 'OCEAN'
        dh.ocean_unit = row[2]
      end
      dh.total_unit = dh.total_unit + row[2]
    end
  end

  def data_holder master_hash, country_code
    master_hash[country_code] ||= HmDataHolder.new
  end
end; end; end