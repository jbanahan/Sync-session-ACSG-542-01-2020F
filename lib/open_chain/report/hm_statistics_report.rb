require 'open_chain/report/report_helper'
module OpenChain
  module Report
    class HmStatisticsReport
      include OpenChain::Report::ReportHelper

      def self.permission? user
        user.view_entries? && (user.company.master? || user.company.alliance_customer_number=='HENNE') 
      end

      def self.run_report run_by, settings={}
        self.new.run run_by, settings
      end

      def run run_by, settings
        start_date = sanitize_date_string settings['start_date']
        end_date = sanitize_date_string settings['end_date']
        qry = <<QRY
select 
(case entries.transport_mode_code when 40 then "AIR" when 11 then "OCEAN" when 30 then "TRUCK" else "OTHER" end) as "Mode", 
(select name from ports where schedule_d_code = entries.entry_port_code) as "Entry Port",
entries.export_country_codes as "Shipment Export Country",
count(*) as "Entries",
sum((select count(*) from containers where containers.entry_id = entries.id)) as "Container Count",
sum((select count(*) from commercial_invoices where commercial_invoices.entry_id = entries.id and length(commercial_invoices.invoice_number) = 6)) as "Orders",
sum(total_invoiced_value) as "Invoice Value",
sum(entered_value) as "Customs Value",
sum(total_duty) as "Duty",
sum(total_fees) as "Fees"
from entries
where customer_number = 'HENNE' and release_date between "#{start_date}" and "#{end_date}"
and (select avg(length(commercial_invoices.invoice_number)) from commercial_invoices where commercial_invoices.entry_id = entries.id) = 6
group by 
entries.transport_mode_code, 
entries.export_country_codes,
(select name from ports where schedule_d_code = entries.entry_port_code)
order by entries.transport_mode_code,
(select name from ports where schedule_d_code = entries.entry_port_code),
entries.export_country_codes;
QRY
        wb = Spreadsheet::Workbook.new
        sheet = wb.create_worksheet :name=>'Statistics'
        # Translate the release, arrival date into Eastern Timezone before trimming the time portion off
        # Moved out of the query because if done in the query we're converting the UTC time to a date and potentially 
        # reporting the wrong date if the release is done between 8-12PM EDT.
        dt_lambda = datetime_translation_lambda("Eastern Time (US & Canada)", true)
        conversions = {"Release" => dt_lambda, "Arrival" => dt_lambda}
        table_from_query sheet, qry, conversions
        workbook_to_tempfile wb, 'HmStatisticsReport-'
      end
    end
  end
end
