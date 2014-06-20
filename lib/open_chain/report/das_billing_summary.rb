require 'open_chain/report/report_helper'
module OpenChain
  module Report
    class DasBillingSummary
      include OpenChain::Report::ReportHelper
      TAX_ID ="857733323RM0001" 
      DATA_TABLE_COLUMNS = [:ent_brok_ref,:ent_entry_num,:ci_invoice_number,:ent_cargo_control_number,
      :ent_cadex_sent_date,:ent_cadex_accept_date,:ent_exam_ordered_date,:ent_pars_ack_date,:ent_direct_shipment_date,
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
        # The case statement in the inner query for the LVS is there so that we still are reporting historical entries using the old $1600 LVS limit
        # and going forward utilize the $2500 limit
        summary_qry = <<QRY
select `Web Links`, `Entry Number`, `Total Value By Entry`, `Invoice Lines`, `Billable Lines`, (`Billable Lines` * if(`lvs`,0.4,0.5)) as "Line Charge", 
if(`lvs`,45,85) as `Brokerage Charge`, `Total Duty`, `Total GST`
from (
select `Web Links`, `Entry Number`, `Entered Value` as `Total Value By Entry`, count(*) as `Invoice Lines`,
if(count(*)>10,count(*)-10,0) as "Billable Lines", (CASE WHEN `Cadex Sent` > '2013-12-02 05:00' THEN if(`Entered Value` > 2500,false,true) ELSE if(`Entered Value` > 1600,false,true) END) as "lvs", `Total Duty`, `Total GST`
from (
select distinct cil.country_origin_code, ent.id as `Web Links`, ent.entered_value as `Entered Value`, ent.entry_number as `Entry Number`, cit.hts_code, ent.total_duty as `Total Duty`, ent.total_gst as `Total GST`, ent.cadex_sent_date as `Cadex Sent`
from entries ent
inner join commercial_invoices ci on ci.entry_id = ent.id
inner join commercial_invoice_lines cil on cil.commercial_invoice_id = ci.id
inner join commercial_invoice_tariffs cit on cil.id = cit.commercial_invoice_line_id
where ent.importer_tax_id = "#{TAX_ID}"
and cadex_sent_date between "#{start_date}" and "#{end_date}"
) root
group by `Web Links` 
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
        table_from_query sheet, qry, {0 => weblink_translation_lambda(CoreModule::ENTRY)}
      end
      def make_raw_sheet wb, entries, run_by 
        raw_sheet = wb.create_worksheet :name=>"Raw Data"

        XlsMaker.add_header_row raw_sheet, 0, DATA_TABLE_COLUMNS.map{|uid| ModelField.find_by_uid(uid).label(false) }

        cursor = 1
        column_widths = []
        entries.each do |ent|
          ent.commercial_invoices.each do |ci|
            ci.commercial_invoice_lines.each do |cil|
              cil.commercial_invoice_tariffs.each do |cit|
                row = []
                DATA_TABLE_COLUMNS.each_with_index do |id,col|
                  mf = ModelField.find_by_uid(id)
                  obj_map = {CoreModule::ENTRY=>ent,CoreModule::COMMERCIAL_INVOICE=>ci,
                    CoreModule::COMMERCIAL_INVOICE_LINE=>cil,CoreModule::COMMERCIAL_INVOICE_TARIFF=>cit}
                  row << mf.process_export(obj_map[mf.core_module], run_by)
                end
                XlsMaker.add_body_row raw_sheet, cursor, row, column_widths
                cursor += 1
              end
            end
          end
        end
      end
    end
  end
end
