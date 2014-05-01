module OpenChain
  class OhlDrawbackParser
    attr_reader :entry
    DOZENS_INDICATORS ||= ["DOZ",'DPR']
    SOURCE_CODE ||= 'OHL Drawback'
    
    # There are two formats for the report from OHL, these maps accomodate both
    SHORT_MAP ||= {
      importer_name:0,
      entry_number:1,
      arrival_date:2,
      entry_port_code:4,
      mpf:7,
      transport_mode_code:8,
      total_invoiced_value:9,
      total_duty:10,
      merchandise_description:11,
      country_origin_code:13,
      entered_value:16,
      hts_code:17,
      po_number:18,
      part_number:20,
      total_duty_direct:21,
      duty_amount:22,
      quantity:23,
      uom:24
    }
    LONG_MAP ||= {
      importer_name:0,
      entry_number:1,
      arrival_date:3,
      entry_port_code:5,
      mpf:8,
      transport_mode_code:9,
      total_invoiced_value:10,
      total_duty:11,
      merchandise_description:12,
      country_origin_code:14,
      entered_value:19,
      hts_code:20,
      po_number:21,
      part_number:23,
      total_duty_direct:24,
      duty_amount:25,
      quantity:26,
      uom:27
    }
    # parse an OHL Drawback File (sample in spec/support/bin folder)
    def self.parse file_path
      sheet = Spreadsheet.open(file_path).worksheet(0) #always first sheet in workbook
      rows = []
      last_entry_num = nil
      entries = []
      map_to_use = nil
      sheet.each 1 do |row| #start at row 1, skipping headers
        entry_num = row[1]
        if entry_num != last_entry_num && !rows.blank?
          entries << OhlDrawbackParser.new(rows,map_to_use).entry
          rows = []
        end
        rows << row
        last_entry_num = entry_num
        map_to_use = (row.length > 28 && !row[28].blank? ? LONG_MAP : SHORT_MAP)
      end
      entries << OhlDrawbackParser.new(rows,map_to_use).entry unless rows.blank?
      entries
    end

    # constructor, don't use, instead use static parse method
    def initialize entry_rows, map_to_use
      @map = map_to_use
      start_time = Time.now
      return if entry_rows.first[@map[:transport_mode_code]].to_s=="-1" #don't load FTZ entries
      process_header entry_rows.first
      entry_rows.each {|r| process_details r}
      @entry.save!
      #set time to process in milliseconds without calling callbacks
      @entry.connection.execute "UPDATE entries SET time_to_process = #{((Time.now-start_time) * 1000).to_i.to_s} WHERE ID = #{@entry.id}"
      @entry
    end

    private 
    def process_header row
      importer_name = row[@map[:importer_name]]
      raise "Importer Name is required." if importer_name.blank?
      c = Company.find_or_create_by_name_and_importer importer_name, true
      @entry = Entry.find_by_entry_number_and_importer_id row[@map[:entry_number]], c.id
      @entry ||= Entry.new(:source_system=>SOURCE_CODE,:importer_id=>c.id,:import_country=>Country.find_by_iso_code('US'),:entry_number=>row[@map[:entry_number]],:total_duty_direct=>0)
      @entry.commercial_invoices.destroy_all 
      @invoice = @entry.commercial_invoices.build(:invoice_number=>'N/A') unless @invoice
      @entry.entry_port_code = row[@map[:entry_port_code]]
      @entry.arrival_date = datetime row[@map[:arrival_date]]
      @entry.mpf = row[@map[:mpf]]
      @entry.transport_mode_code = row[@map[:transport_mode_code]].to_s
      @entry.total_invoiced_value = row[@map[:total_invoiced_value]]
      @entry.total_duty = row[@map[:total_duty]]
      @entry.merchandise_description = row[@map[:merchandise_description]]
    end
    def process_details row
      @line_number ||= 1
      line = @invoice.commercial_invoice_lines.build(:line_number=>@line_number)
      line.part_number = row[@map[:part_number]]
      line.po_number = row[@map[:po_number]]
      line.quantity = DOZENS_INDICATORS.include?(row[@map[:uom]]) ? row[@map[:quantity]]*12 : row[@map[:quantity]]
      line.country_origin_code = get_country_of_origin row[@map[:country_origin_code]]
      t = line.commercial_invoice_tariffs.build
      t.duty_amount = row[@map[:duty_amount]]
      t.classification_qty_1 = row[@map[:quantity]]
      t.classification_uom_1 = row[@map[:uom]]
      t.hts_code = row[@map[:hts_code]].gsub('.','') if row[@map[:hts_code]]
      t.entered_value = row[@map[:entered_value]]
      @entry.total_duty_direct += row[@map[:total_duty_direct]] unless row[@map[:total_duty_direct]].nil?
      @line_number += 1
    end
    
    private
    #convert excel spreadsheet date column to US Eastern Date/Time
    def datetime v
      ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse(v.strftime("%Y-%m-%d")) unless v.nil?
    end

    def get_country_of_origin val
      val.match(/^[A-Z][A-Z]$/) ? val : ""
    end
  end
end
