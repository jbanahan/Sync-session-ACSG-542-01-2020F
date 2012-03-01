module OpenChain
  class OhlDrawbackParser
    SOURCE_CODE = 'OHL Drawback'
    # parse an OHL Drawback File (sample in spec/support/bin folder)
    def self.parse file_path
      sheet = Spreadsheet.open(file_path).worksheet(0) #always first sheet in workbook
      rows = []
      last_entry_num = nil
      sheet.each 1 do |row| #start at row 1, skipping headers
        entry_num = row[1]
        if entry_num != last_entry_num && !rows.blank?
          OhlDrawbackParser.new rows
          rows = []
        end
        rows << row
        last_entry_num = entry_num
      end
      OhlDrawbackParser.new rows unless rows.blank?
      true #return true so we don't return the last parser used
    end

    # constructor, don't use, instead use static parse method
    def initialize entry_rows
      start_time = Time.now
      return if entry_rows.first[8].to_s=="-1" #don't load FTZ entries
      process_header entry_rows.first
      entry_rows.each {|r| process_details r}
      @entry.save!
      #set time to process in milliseconds without calling callbacks
      @entry.connection.execute "UPDATE entries SET time_to_process = #{((Time.now-start_time) * 1000).to_i.to_s} WHERE ID = #{@entry.id}"
    end

    private 
    def process_header row
      importer_name = row[0]
      raise "Importer Name is required." if importer_name.blank?
      c = Company.find_or_create_by_name_and_importer importer_name, true
      @entry = Entry.find_by_entry_number_and_importer_id row[1], c.id
      @entry ||= Entry.new(:source_system=>SOURCE_CODE,:importer_id=>c.id,:import_country=>Country.find_by_iso_code('US'),:entry_number=>row[1],:total_duty_direct=>0)
      @entry.commercial_invoices.destroy_all 
      @invoice = @entry.commercial_invoices.build(:invoice_number=>'N/A') unless @invoice
      @entry.entry_port_code = row[4]
      @entry.arrival_date = datetime row[2]
      @entry.mpf = row[7]
      @entry.transport_mode_code = row[8].to_s
      @entry.total_invoiced_value = row[9]
      @entry.total_duty = row[10]
      @entry.merchandise_description = row[11]
    end
    def process_details row
      @line_number ||= 1
      line = @invoice.commercial_invoice_lines.build(:line_number=>@line_number)
      line.part_number = row[17]
      line.po_number = row[15]
      t = line.commercial_invoice_tariffs.build
      t.duty_amount = row[19]
      t.classification_qty_1 = row[20]
      t.classification_uom_1 = row[21]
      t.hts_code = row[14].gsub('.','') if row[14]
      t.entered_value = row[13]
      @entry.total_duty_direct += row[18] unless row[18].nil?
      @line_number += 1
    end
    
    #convert excel spreadsheet date column to US Eastern Date/Time
    def datetime v
      ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse(v.strftime("%Y-%m-%d")) unless v.nil?
    end
  end
end
