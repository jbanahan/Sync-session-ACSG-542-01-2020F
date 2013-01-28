module OpenChain
  module Report
    class DasBillingSummary
      DATE_FORMAT = Spreadsheet::Format.new :number_format=>'YYYY-MM-DD'
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
        start_date = settings['start_date']
        end_date = settings['end_date']
        summary_qry = <<QRY
select `Entry Number`, `DAS Invoice Number`, `Total Value By Entry`, `Invoice Lines`, `Billable Lines`, (`Billable Lines` * if(`lvs`,0.4,0.5)) as "Line Charge", 
if(`lvs`,45,85) as `Brokerage Charge`, `Total Duty`, `Total GST`
from (
select `Entry Number`, `Invoice Number` as `DAS Invoice Number`, `Entered Value` as `Total Value By Entry`, count(*) as `Invoice Lines`,
if(count(*)>10,count(*)-10,0) as "Billable Lines", if(`Entered Value` > 1600,false,true) as "lvs", `Total Duty`, `Total GST`
from (
select distinct cil.country_origin_code, ent.id, ci.invoice_number as `Invoice Number`, ent.entered_value as `Entered Value`, ent.entry_number as `Entry Number`, cit.hts_code, ent.total_duty as `Total Duty`, ent.total_gst as `Total GST` 
from entries ent
inner join commercial_invoices ci on ci.entry_id = ent.id
inner join commercial_invoice_lines cil on cil.commercial_invoice_id = ci.id
inner join commercial_invoice_tariffs cit on cil.id = cit.commercial_invoice_line_id
where ent.importer_tax_id = "#{TAX_ID}"
and cadex_sent_date between "#{start_date}" and "#{end_date}"
) root
group by `Entered Value` 
) middle
QRY
        wb = Spreadsheet::Workbook.new
        
        entries = Entry.where(:importer_tax_id=>TAX_ID).where("entries.cadex_sent_date between ? and ?",start_date,end_date)
          .includes(:commercial_invoices=>{:commercial_invoice_lines=>:commercial_invoice_tariffs})
        
        make_summary_sheet wb, summary_qry
        make_raw_sheet wb, entries, run_by

        t = Tempfile.new(['das_billing','.xls'])
        wb.write t.path
        t
      end

      private 
      def self.make_summary_sheet wb, qry
        rs = Entry.connection.execute qry
        sheet = wb.create_worksheet :name=>"Summary"
        cursor = 0
        row = sheet.row(cursor)
        rs.fields.each {|f| row.push << f }
        cursor += 1
        rs.each do |vals|
          row = sheet.row(cursor)
          vals.each_with_index do |v,col|
            write_val sheet, row, cursor, col, v
          end
          cursor += 1
        end
      end
      def self.make_raw_sheet wb, entries, run_by 
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
      def self.write_val sheet, row, row_num, col_num, val
        v = val
        v = v.to_f if v.is_a?(BigDecimal)
        row[col_num] = v
        if v.respond_to?(:strftime)
          sheet.row(row_num).set_format(col_num,DATE_FORMAT)
        end
      end
    end
  end
end
