module OpenChain
  module Report
    class EddieBauerStatementSummary

      #do not create objects for this class, use the #run_report method
      def initialize(run_by,mode='not_paid')
        @run_by = run_by
        @mode = mode
      end
      
      def self.permission? user
        (Rails.env=='development' || MasterSetup.get.system_code=='www-vfitrack-net') && user.company.master?
      end

      def self.run_report run_by, settings={}
        mode = HashWithIndifferentAccess.new(settings)[:mode]
        self.new(run_by,mode).run
      end

      def run
        wb = Spreadsheet::Workbook.new
        @summary_sheet = wb.create_worksheet :name=>"Summary"
        @detail_sheet = wb.create_worksheet :name=>"Details"
        @detail_cursor = 0
        
        #write detail headings
        r = @detail_sheet.row(@detail_cursor)
        ["Statement #","ACH #","Entry #","PO","Business","Invoice",
          "Duty Rate","Duty","Taxes / Fees","ACH Date",
          "Statement Date","Release Date","Unique ID"].each_with_index do |h,i|
          r[i] = h
        end
        @detail_cursor += 1

        entries = find_entries
        summary_hash = {}
        entries.each do |ent|
          raise "You do not have permission to view the entries related to this report." unless ent.can_view?(@run_by)
          monthly = ent.monthly_statement_number
          monthly = '' if monthly.blank?
          summary_hash[monthly] ||= {}
          statement_hash = summary_hash[ent.monthly_statement_number]
          ent.commercial_invoices.each do |ci|
            ci.commercial_invoice_lines.each do |cil|
              r = @detail_sheet.row(@detail_cursor)
              r[0] = monthly 
              r[1] = ent.daily_statement_number
              r[2] = ent.entry_number
              r[9] = ent.daily_statement_approved_date
              r[10] = ent.monthly_statement_received_date
              r[11] = ent.release_date
              po = cil.po_number
              po = '0-0' if po.blank?
              business = po.split("-").last
              r[3] = po.split("-").first
              r[4] = business
              duty_rate = BigDecimal("0.00") 
              line_duty = BigDecimal("0.00") 
              cil.commercial_invoice_tariffs.each do |cit|
                duty_rate = (duty_rate > cit.duty_rate) ? duty_rate : cit.duty_rate
                line_duty += cit.duty_amount.blank? ? 0 : cit.duty_amount
              end
              r[6] = duty_rate.to_f * 100
              r[7] = line_duty.to_f
              line_fees = fees(cil).to_f
              r[8] = line_fees 
              r[12] = "#{ent.entry_number}/#{duty_rate*100}/#{ci.invoice_number}"

              #prep summary page data
              statement_hash[business] ||= {:duty=>BigDecimal("0.00"),
                :fees=>BigDecimal("0.00"),
                :statement_date=>ent.monthly_statement_received_date
              }
              business_hash = statement_hash[business]
              business_hash[:duty] += line_duty
              business_hash[:fees] += line_fees
              r[5] = ci.invoice_number
              @detail_cursor += 1
            end
          end
        end

        @summary_cursor = 0
        r = @summary_sheet.row(@summary_cursor)
        ["Statement #","Business","Duty","Taxes / Fees","Statement Date"].each_with_index {|t,i| r[i] = t}
        @summary_cursor += 1

        summary_hash.each do |stmt,bh|
          bh.each do |business,vals|
            r = @summary_sheet.row(@summary_cursor)
            r[0] = stmt
            r[1] = business
            r[2] = vals[:duty].to_f
            r[3] = vals[:fees].to_f
            r[4] = vals[:statement_date]
            @summary_cursor += 1
          end
        end

        t = Tempfile.new(["EddieBauerStatementSummary",".xls"])
        wb.write t
        t
      end
      def find_entries
        r = nil
        if @mode && @mode.to_s=='previous_month'
          r = Entry.
            where(:importer_id=>Company.find_by_alliance_customer_number("EDDIE").id).
            where("MONTH(entries.release_date) = ? AND YEAR(entries.release_date) = ?",1.month.ago.month,1.month.ago.year).
            order("entries.release_date ASC")
        else
          r = Entry.
            where(:importer_id=>Company.find_by_alliance_customer_number("EDDIE").id).
            where("length(daily_statement_number) > 0").
            where("monthly_statement_paid_date is null")
        end
        r
      end
      private
      def fees cil
        r = BigDecimal("0.00")
        [:hmf,:prorated_mpf,:cotton_fee].each do |k|
          v = cil[k]
          r += v.blank? ? 0 : v
        end
        r
      end
    end
  end
end

