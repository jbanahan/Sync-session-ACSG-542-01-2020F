require 'bigdecimal'
module OpenChain
  class AllianceParser

    DATE_MAP = {'00012'=>:arrival_date,
      '00016'=>:entry_filed_date,
      '00019'=>:release_date,
      '99202'=>:first_release_date,
      '00052'=>:free_date,
      '00028'=>:last_billed_date,
      '00032'=>:invoice_paid_date,
      '00044'=>:liquidation_date
    }
    # take the text inside an internet tracking file from alliance and create/update the entry
    def self.parse file_content
      entry_lines = []
      file_content.lines.each do |line|
        prefix = line[0,4]
        if !entry_lines.empty? && prefix=="SH00"
          AllianceParser.new.parse_entry entry_lines 
          entry_lines = []
        end
        entry_lines << line
      end
      AllianceParser.new.parse_entry entry_lines if !entry_lines.empty?
    end

    def parse_entry rows
      Entry.transaction do 
        start_time = Time.now
        rows.each do |r|
          break if @skip_entry
          prefix = r[0,4]
          case prefix
            when "SH00"
              process_sh00 r
            when "SD00"
              process_sd00 r
            when "IH00"
              process_ih00 r
            when "IT00"
              process_it00 r
            when "IL00"
              process_il00 r
            when "SI00"
              process_si00 r
          end
        end
        if !@skip_entry
            @entry.it_numbers = @it_numbers.nil? ? "" : @it_numbers.join("\n")
            @entry.master_bills_of_lading = @mbols.nil? ? "" : @mbols.join("\n")
            @entry.house_bills_of_lading = @hbols.nil? ? "" : @hbols.join("\n")
            @entry.sub_house_bills_of_lading = @sub_bols.nil? ? "" : @sub_bols.join("\n")
            @entry.time_to_process = ((Time.now-start_time) * 1000).to_i #milliseconds
            @entry.save! if @entry
        end
        @skip_entry = false
      end
    end

    private 
    # header
    def process_sh00 r
      brok_ref = r[6,8]
      @entry = Entry.find_by_broker_reference brok_ref
      if @entry && @entry.last_exported_from_source && @entry.last_exported_from_source > parse_date_time(r[24,12]) #if current is newer than file
        @skip_entry = true
      else
        @entry = Entry.new(:broker_reference=>brok_ref) unless @entry
        @entry.customer_number = r[14,10].strip
        @entry.last_exported_from_source = parse_date_time r[24,12]
        @entry.company_number = r[36,2].strip
        @entry.division_number = r[38,4].strip
        @entry.customer_name = r[42,35].strip
        @entry.entry_type = r[166,2].strip
        @entry.entry_number = r[168,12]
      end
    end

    # date
    def process_sd00 r
      d = r[9,12]
      dp = DATE_MAP[r[4,5]]
      @entry.attributes= {dp=>parse_date_time(d)} if dp
    end

    # invoice header
    def process_ih00 r
      @invoice = nil
      @invoice = @entry.broker_invoices.where(:suffix=>r[4,2]).first if @entry.id  #existing entry, check for existing invoice
      @invoice = @entry.broker_invoices.build(:suffix=>r[4,2]) unless @invoice
      @invoice.invoice_date = parse_date r[6,8]
      @invoice.invoice_total = parse_currency r[24,11]
      @invoice.customer_number = r[14,10].strip
      @invoice.bill_to_name = r[83,35].strip
      @invoice.bill_to_address_1 = r[118,35].strip
      @invoice.bill_to_address_2 = r[153,35].strip
      @invoice.bill_to_city = r[188,35].strip
      @invoice.bill_to_state = r[223,2].strip
      @invoice.bill_to_zip = r[225,9].strip
      @invoice.bill_to_country = Country.find_by_iso_code(r[234,2]) unless r[234,2].strip.blank?
      @invoice.save! unless @invoice.id.blank? #save existing that are updated
      @invoice.broker_invoice_lines.destroy_all
    end

    # invoice line
    def process_il00 r
      line = @invoice.broker_invoice_lines.build
      line.charge_code = r[4,4].strip
      line.charge_description = r[8,35].strip
      line.charge_amount = parse_currency r[43,11]
      line.vendor_name = r[54,30].strip
      line.vendor_reference = r[84,15].strip
      line.charge_type = r[99,1]
      line.save unless @invoice.id.blank?
    end

    # invoice trailer
    def process_it00 r
      @invoice = nil
    end

    # tracking numbers
    def process_si00 r
      @mbols ||= []
      @hbols ||= []
      @sub_bols ||= []
      @it_numbers ||= []
      it_number = r[4,12].strip
      mbol = r[16,16].strip
      hbol = r[32,12].strip
      sub = r[44,12].strip
      @it_numbers << it_number unless it_number.blank?
      @mbols << mbol unless mbol.blank?
      @hbols << hbol unless hbol.blank?
      @sub_bols << sub unless sub.blank?
    end

    def parse_date str
      Date.parse str
    end
    def parse_date_time str
      ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse str
    end
    def parse_currency str
      BigDecimal.new str.insert(-3,"."), 2
    end
  end
end
