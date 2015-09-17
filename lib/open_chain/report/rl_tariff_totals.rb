require 'open_chain/report/report_helper'
module OpenChain
  module Report
    class RlTariffTotals
      include OpenChain::Report::ReportHelper

      def self.permission? user
        user.view_products? && user.company.master? && MasterSetup.get.system_code=='polo'
      end

      def self.run_report(user, settings = {})
        self.new.run(settings)
      end

      def self.run_schedulable opts_hash={}
        last_month = DateTime.now.utc.to_date - 1.month
        start_date_time = last_month.beginning_of_month.to_datetime.to_s(:db)
        end_date_time = (last_month.end_of_month + 1.day).to_datetime.to_s(:db)
        self.new.send_email('email' => opts_hash['email'], 'start_date_time' => start_date_time, 'end_date_time' => end_date_time)
      end

      def create_workbook(start, finish)
        wb = XlsMaker.create_workbook "GCC Stats"
        XlsMaker.create_sheet wb, "GCSEA Stats"
        table_from_query wb.worksheet(0), gcc_query(start, finish)
        table_from_query wb.worksheet(1), gcsea_query(start, finish)
        wb
      end

      def run(settings)
        start_date_time = DateTime.parse(settings['start_date']).to_s(:db)
        end_date_time = (DateTime.parse(settings['end_date']) + 1.day).to_s(:db)
        wb = create_workbook(start_date_time, end_date_time)
        workbook_to_tempfile wb, 'RlTariffTotals-'
      end

      def send_email(settings)
        wb = create_workbook(settings['start_date_time'], settings['end_date_time'])
        
        workbook_to_tempfile wb, 'RlTariffTotals-' do |t|
          start_date_formatted = Date.parse(settings['start_date_time']).strftime("%-m-%-d-%y")
          end_date_formatted = Date.parse(settings['end_date_time']).strftime("%-m-%-d-%y")
          subject = "Tariff Totals for the Period #{start_date_formatted} to #{end_date_formatted}"
          body = "<p>Report attached.<br>--This is an automated message, please do not reply. <br> This message was generated from VFI Track</p>".html_safe
          OpenMailer.send_simple_html(settings['email'], subject, body, t).deliver!
        end
      end

      def gcc_query(start, finish)
        <<-SQL
          select
            (select count(*)
             from products
             inner join classifications on products.id = classifications.product_id and classifications.country_id in (select id from countries where iso_code in ('US','CA','IT'))
             inner join tariff_records on classifications.id = tariff_records.classification_id
             and tariff_records.updated_at between '#{start}' and '#{finish}') as 'Total Tariffs Updated',

            (select count(*)
             from products
             inner join classifications on products.id = classifications.product_id and classifications.country_id in (select id from countries where iso_code in ('US','CA','IT'))
             inner join tariff_records on classifications.id = tariff_records.classification_id
             and tariff_records.created_at between '#{start}' and '#{finish}') as 'Total Tariffs Created',
                 
            (select count(*)
             from products
             inner join classifications on products.id = classifications.product_id and classifications.country_id in (select id from countries where iso_code  = 'US')
             inner join tariff_records on classifications.id = tariff_records.classification_id
             and tariff_records.created_at between '#{start}' and '#{finish}') as 'Total Tariffs Created - US',
                 
            (select count(*)
             from products
             inner join classifications on products.id = classifications.product_id and classifications.country_id in (select id from countries where iso_code  = 'CA')
             inner join tariff_records on classifications.id = tariff_records.classification_id
             and tariff_records.created_at between '#{start}' and '#{finish}') as 'Total Tariffs Created - CA',
                 
            (select count(*)
             from products
             inner join classifications on products.id = classifications.product_id and classifications.country_id in (select id from countries where iso_code  = 'IT')
             inner join tariff_records on classifications.id = tariff_records.classification_id
             and tariff_records.created_at between '#{start}' and '#{finish}') as 'Total Tariffs Created - IT',
                 
            (select count(*) from (
             select distinct hts_1
             from products
             inner join classifications on products.id = classifications.product_id and classifications.country_id in (select id from countries where iso_code in ('US','CA','IT'))
             inner join tariff_records on classifications.id = tariff_records.classification_id
             and tariff_records.updated_at between '#{start}' and '#{finish}') x) as 'Total HTS Numbers'
        SQL
      end

      def gcsea_query(start, finish)
        <<-SQL
          select
            (select count(*)
             from products
             inner join classifications on products.id = classifications.product_id and classifications.country_id in (select id from countries where iso_code in ('AU','CN','HK','IN','ID','JP','KR','MO','MY','NZ','PH','SG','TW','TH','VN'))
             inner join tariff_records on classifications.id = tariff_records.classification_id
             and tariff_records.updated_at between '#{start}' and '#{finish}') as 'Total Tariffs Updated',
              
             (select count(*)
              from products
              inner join classifications on products.id = classifications.product_id and classifications.country_id in (select id from countries where iso_code in ('AU','CN','HK','IN','ID','JP','KR','MO','MY','NZ','PH','SG','TW','TH','VN'))
              inner join tariff_records on classifications.id = tariff_records.classification_id
              and tariff_records.created_at between '#{start}' and '#{finish}') as 'Total Tariffs Created',
              
             (select count(*)
              from products
              inner join classifications on products.id = classifications.product_id and classifications.country_id in (select id from countries where iso_code  = 'AU')
              inner join tariff_records on classifications.id = tariff_records.classification_id
              and tariff_records.created_at between '#{start}' and '#{finish}') as 'Total Tariffs Created - AU',
             
             (select count(*)
              from products
              inner join classifications on products.id = classifications.product_id and classifications.country_id in (select id from countries where iso_code = 'CN')
              inner join tariff_records on classifications.id = tariff_records.classification_id
              and tariff_records.created_at between '#{start}' and '#{finish}') as 'Total Tariffs Created - CN',
             
             (select count(*)
              from products
              inner join classifications on products.id = classifications.product_id and classifications.country_id in (select id from countries where iso_code = 'HK')
              inner join tariff_records on classifications.id = tariff_records.classification_id
              and tariff_records.created_at between '#{start}' and '#{finish}') as 'Total Tariffs Created - HK',
             
             (select count(*)
              from products
              inner join classifications on products.id = classifications.product_id and classifications.country_id in (select id from countries where iso_code = 'IN')
              inner join tariff_records on classifications.id = tariff_records.classification_id
              and tariff_records.created_at between '#{start}' and '#{finish}') as 'Total Tariffs Created - IN',
             
             (select count(*)
              from products
              inner join classifications on products.id = classifications.product_id and classifications.country_id in (select id from countries where iso_code = 'ID')
              inner join tariff_records on classifications.id = tariff_records.classification_id
              and tariff_records.created_at between '#{start}' and '#{finish}') as 'Total Tariffs Created - ID',
             
             (select count(*)
              from products
              inner join classifications on products.id = classifications.product_id and classifications.country_id in (select id from countries where iso_code = 'JP')
              inner join tariff_records on classifications.id = tariff_records.classification_id
              and tariff_records.created_at between '#{start}' and '#{finish}') as 'Total Tariffs Created - JP',
             
             (select count(*)
              from products
              inner join classifications on products.id = classifications.product_id and classifications.country_id in (select id from countries where iso_code = 'KR')
              inner join tariff_records on classifications.id = tariff_records.classification_id
              and tariff_records.created_at between '#{start}' and '#{finish}') as 'Total Tariffs Created - KR',
             
             (select count(*)
              from products
              inner join classifications on products.id = classifications.product_id and classifications.country_id in (select id from countries where iso_code = 'MO')
              inner join tariff_records on classifications.id = tariff_records.classification_id
              and tariff_records.created_at between '#{start}' and '#{finish}') as 'Total Tariffs Created - MO',
             
             (select count(*)
              from products
              inner join classifications on products.id = classifications.product_id and classifications.country_id in (select id from countries where iso_code = 'MY')
              inner join tariff_records on classifications.id = tariff_records.classification_id
              and tariff_records.created_at between '#{start}' and '#{finish}') as 'Total Tariffs Created - MY',
             
             (select count(*)
              from products
              inner join classifications on products.id = classifications.product_id and classifications.country_id in (select id from countries where iso_code = 'NZ')
              inner join tariff_records on classifications.id = tariff_records.classification_id
              and tariff_records.created_at between '#{start}' and '#{finish}') as 'Total Tariffs Created - NZ',
             
             (select count(*)
              from products
              inner join classifications on products.id = classifications.product_id and classifications.country_id in (select id from countries where iso_code = 'PH')
              inner join tariff_records on classifications.id = tariff_records.classification_id
              and tariff_records.created_at between '#{start}' and '#{finish}') as 'Total Tariffs Created - PH',
             
             (select count(*)
              from products
              inner join classifications on products.id = classifications.product_id and classifications.country_id in (select id from countries where iso_code = 'SG')
              inner join tariff_records on classifications.id = tariff_records.classification_id
              and tariff_records.created_at between '#{start}' and '#{finish}') as 'Total Tariffs Created - SG',
             
             (select count(*)
              from products
              inner join classifications on products.id = classifications.product_id and classifications.country_id in (select id from countries where iso_code = 'TW')
              inner join tariff_records on classifications.id = tariff_records.classification_id
              and tariff_records.created_at between '#{start}' and '#{finish}') as 'Total Tariffs Created - TW',
            
             (select count(*)
              from products
              inner join classifications on products.id = classifications.product_id and classifications.country_id in (select id from countries where iso_code = 'TH')
              inner join tariff_records on classifications.id = tariff_records.classification_id
              and tariff_records.created_at between '#{start}' and '#{finish}') as 'Total Tariffs Created - TH',
             
             (select count(*)
              from products
              inner join classifications on products.id = classifications.product_id and classifications.country_id in (select id from countries where iso_code = 'VN')
              inner join tariff_records on classifications.id = tariff_records.classification_id
              and tariff_records.created_at between '#{start}' and '#{finish}') as 'Total Tariffs Created - VN',
             
             (select count(*) from (
              select distinct hts_1
              from products
              inner join classifications on products.id = classifications.product_id and classifications.country_id in (select id from countries where iso_code in ('AU','CN','HK','IN','ID','JP','KR','MO','MY','NZ','PH','SG','TW','TH','VN'))
              inner join tariff_records on classifications.id = tariff_records.classification_id
              and tariff_records.updated_at between '#{start}' and '#{finish}') x) as 'Total HTS Numbers'
        SQL

      end
    end
  end
end