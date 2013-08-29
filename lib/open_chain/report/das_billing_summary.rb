require 'open_chain/report/report_helper'
module OpenChain
  module Report
    class DasBillingSummary
      include OpenChain::Report::ReportHelper
      TAX_ID ="857733323RM0001" 
      DATA_TABLE_COLUMNS = [:ent_brok_ref,:ent_entry_num,:ci_invoice_number,:ent_cargo_control_number,
      :ent_cadex_sent_date,:ent_cadex_accept_date,:ent_pars_ack_date,:ent_direct_shipment_date,
      :cil_line_number,:cil_part_number,:cil_country_origin_code,:ent_value_for_duty_code,
      :cit_hts_code,:cit_classification_qty_1,:cit_classification_uom_1,:cit_entered_value,
      :cil_units,:cil_uom,:cil_value,:ent_excise_amount,:ent_excise_rate_code,
      :ent_gst_rate_code,:ent_gst_amount,:ent_sima_amount,:cit_duty_amount]

      def self.permission? user
        user.company.master? && user.view_broker_invoices?
      end

      #expects start_date and end_date
      def self.run_report run_by, settings={}
        self.new.run run_by, settings
      end

      def run run_by, settings
        start_date = sanitize_date_string settings['start_date'], run_by.time_zone
        end_date = sanitize_date_string settings['end_date'], run_by.time_zone
        summary_qry = <<QRY
select `Entry Number`, `Total Value By Entry`, `Invoice Lines`, `Billable Lines`, (`Billable Lines` * if(`lvs`,0.4,0.5)) as "Line Charge", 
if(`lvs`,45,85) as `Brokerage Charge`, `Total Duty`, `Total GST`
from (
select `Id`, `Entry Number`, `Entered Value` as `Total Value By Entry`, count(*) as `Invoice Lines`,
if(count(*)>10,count(*)-10,0) as "Billable Lines", if(`Entered Value` > 1600,false,true) as "lvs", `Total Duty`, `Total GST`
from (
select distinct cil.country_origin_code, ent.id as `Id`, ent.entered_value as `Entered Value`, ent.entry_number as `Entry Number`, cit.hts_code, ent.total_duty as `Total Duty`, ent.total_gst as `Total GST` 
from entries ent
inner join commercial_invoices ci on ci.entry_id = ent.id
inner join commercial_invoice_lines cil on cil.commercial_invoice_id = ci.id
inner join commercial_invoice_tariffs cit on cil.id = cit.commercial_invoice_line_id
where ent.importer_tax_id = "#{TAX_ID}"
and cadex_sent_date between "#{start_date}" and "#{end_date}"
) root
group by `Id` 
) middle
QRY
        wb = Spreadsheet::Workbook.new
        
        entries = Entry.where(:importer_tax_id=>TAX_ID).where("entries.cadex_sent_date between ? and ?",start_date,end_date)
          .includes(:commercial_invoices=>{:commercial_invoice_lines=>:commercial_invoice_tariffs})
        
        make_summary_sheet wb, summary_qry
        make_raw_sheet wb, entries, run_by

        workbook_to_tempfile wb, 'das_billing'
      end

      private 
      def make_summary_sheet wb, qry
        sheet = wb.create_worksheet :name=>"Summary"
        table_from_query sheet, qry
      end
      def make_raw_sheet wb, entries, run_by 
        raw_sheet = wb.create_worksheet :name=>"Raw Data"
        cursor = 0
        row = raw_sheet.row(cursor)
        DATA_TABLE_COLUMNS.each {|id| 
          mf = ModelField.find_by_uid(id)
          puts id if mf.nil?
          row.push mf.label(false)
        }
        cursor += 1
        entries.each do |ent|
          ent.commercial_invoices.each do |ci|
            ci.commercial_invoice_lines.each do |cil|
              cil.commercial_invoice_tariffs.each do |cit|
                row = raw_sheet.row(cursor)
                DATA_TABLE_COLUMNS.each_with_index do |id,col|
                  mf = ModelField.find_by_uid(id)
                  obj_map = {CoreModule::ENTRY=>ent,CoreModule::COMMERCIAL_INVOICE=>ci,
                    CoreModule::COMMERCIAL_INVOICE_LINE=>cil,CoreModule::COMMERCIAL_INVOICE_TARIFF=>cit}
                  write_val raw_sheet, row, cursor, col, mf.process_export(obj_map[mf.core_module],run_by)
                end
                cursor += 1
              end
            end
          end
        end
      end
    end
  end
end
