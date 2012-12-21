module OpenChain
  module Report
    class MarcJacobsFreightBudget

      def self.permission? u
        u.company.master? && u.view_broker_invoices?
      end
      def self.run_report run_by, settings={}
        inner_settings={'year'=>Time.now.year,'month'=>Time.now.month}.merge(settings)
        self.new(run_by,inner_settings['year'],inner_settings['month']).run 
      end

      #don't call this, use run_report
      def initialize(run_by,year,month)
        @run_by = run_by
        @year = year.to_i
        @month = month.to_i
      end

      def run
        wb = Spreadsheet::Workbook.new
        s = wb.create_worksheet :name=>"Report"
        cursor = 0
        r = s.row(cursor)
        ["Broker","Month","HAWB","Brokerage Fee","Duty","Total Fees","Master","Forwarder"].each_with_index do |lbl,i|
          r[i] = lbl
        end
        cursor += 1
        importer = Company.find_by_alliance_customer_number("MARJAC")
        entries = Entry.
          where("YEAR(release_date) = ? AND MONTH(release_date) = ?",@year,@month).
          where(:importer_id=>(importer ? importer.id : -1))
        entries.each do |ent|

          raise "You do not have permission to view the entries on this report." unless ent.can_view?(@run_by)

          #running counts to figure out what last value should be
          r_brok = BigDecimal("0.00") 
          r_duty = BigDecimal("0.00")
          r_fees = BigDecimal("0.00")
        
          hb_str = ent.house_bills_of_lading
          hb_str = ' ' if hb_str.blank?
          hbols = hb_str.split("\n")
          hbols.each_with_index do |hb,i|
            r = s.row(cursor)
            r[0] = 'Vandegrift'
            r[1] = Date::MONTHNAMES[@month]
            r[2] = hb
            if i == (hbols.size-1)
              #write the remaining value in the last row
              r[3] = (ent.broker_invoice_total - r_brok).to_f
              r[4] = (ent.total_duty - r_duty).to_f
              r[5] = (ent.total_fees - r_fees).to_f
            else
              #prorate the value
              val_brok = BigDecimal.new(ent.broker_invoice_total / hbols.size).round(2)
              val_duty = BigDecimal.new(ent.total_duty / hbols.size).round(2)
              val_fees = BigDecimal.new(ent.total_fees / hbols.size).round(2)

              #increment the running total
              r_brok += val_brok 
              r_duty += val_duty
              r_fees += val_fees

              #write the values
              r[3] = val_brok.to_f
              r[4] = val_duty.to_f
              r[5] = val_fees.to_f
            end
            r[6] = ent.master_bills_of_lading
            cursor += 1
          end
        end
        t = Tempfile.new ['MarcJacobsFreightBudget','.xls']
        wb.write t
        t
      end

    end
  end
end
