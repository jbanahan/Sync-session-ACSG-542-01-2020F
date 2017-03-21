require 'open_chain/report/report_helper'

module OpenChain; module Report; class PpqByPoReport
  include OpenChain::Report::ReportHelper

  def self.permission? user
    user.view_entries?
  end

  def self.run_report run_by, settings={}
    self.new.run run_by, settings
  end

  def run run_by, settings
    customer_numbers = rows_to_csv settings['customer_numbers']
    po_numbers = rows_to_csv settings['po_numbers']
    wb = create_workbook customer_numbers, po_numbers, run_by
    workbook_to_tempfile wb, 'PPQ-By-PO-', file_name: "PPQ By PO Numbers.xls"
  end

  def create_workbook customer_numbers, po_numbers, run_by
    wb, sheet = XlsMaker.create_workbook_and_sheet "PPQ By PO Numbers"
    table_from_query sheet, query(customer_numbers,po_numbers,run_by), conversions(run_by.time_zone)
    wb
  end

  def conversions time_zone
    {"Entry Number" => datetime_translation_lambda(time_zone)}
  end
  
  def rows_to_csv str
    return '' unless str
    c = ActiveRecord::Base.connection
    str.lines.map { |s| s.blank? ? nil : c.quote(s.strip) }.compact.uniq.join(',')
  end

  def query customer_numbers, po_numbers, run_by
    return "select \"PO AND CUSTOMER REQUIRED\" as \"ERROR\"" if customer_numbers.blank? || po_numbers.blank?
    <<-SQL
    select entries.entry_number as 'Entry Number', entries.release_date as 'Release Date', cit.hts_code as 'HTS Code', cil.po_number as 'PO Number', cil.part_number as 'Part Number', 
cic.detailed_description as 'Description',
cic.value as 'PPQ Value',
cic.name as 'PPQ Name',
cic.quantity as 'PPQ Quanitity',
cic.unit_of_measure as 'UOM',
cic.genus as 'Genus',
cic.species as 'Species',
cic.harvested_from_country as 'Harvest Country',
cic.percent_recycled_material as 'Percent Recycled'
from entries
inner join commercial_invoices ci on ci.entry_id = entries.id
inner join commercial_invoice_lines cil on cil.commercial_invoice_id = ci.id
inner join commercial_invoice_tariffs cit on cit.commercial_invoice_line_id = cil.id
inner join commercial_invoice_lacey_components cic on cic.commercial_invoice_tariff_id = cit.id
where entries.customer_number IN  (#{customer_numbers}) and cil.po_number IN (#{po_numbers})
AND #{Entry.search_where(run_by)}
    SQL
  end
end; end; end
