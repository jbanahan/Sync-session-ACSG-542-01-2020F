require 'open_chain/xl_client'
require 'open_chain/under_armour_receiving_parser'
module OpenChain
  class UnderArmourFtzParser
    IMPORTER_NAME = "UNDER ARMOUR INC."
    SOURCE_CODE = "UNDER ARMOUR FTZ"
    GENERIC_UA_VENDOR_NAME = "UNDER ARMOUR FTZ VENDOR"
    # parse file from s3, must provide the customs entry date since it's not in the file
    def self.parse_s3 s3_path, entry_date, box_37_value, box_40_value, port_code, entered_value, mpf, first_row=1
      other_data = {:entry_date=>entry_date,:box_37_value=>box_37_value,
        :box_40_value=>box_40_value,:port_code=>port_code, 
        :entered_value=>entered_value,:mpf=>mpf}
      product_cache = {}
      client = OpenChain::XLClient.new s3_path
      last_row_number = client.last_row_number 0
      val_set = []
      last_entry_number = nil
      (first_row..last_row_number).each do |row_num|
        row = client.get_row 0, row_num
        val_hash = {}
        row.each do |cell|
          val_hash[cell['position']['column']] = cell['cell']['value']
        end
        entry_number = val_hash[1]
        raise "Row #{row_num} does not have Entry number." unless entry_number
        if entry_number != last_entry_number && !val_set.empty?
          UnderArmourFtzParser.new val_set, other_data, product_cache
          val_set = []
        end
        last_entry_number = entry_number
        val_set << val_hash
      end
      UnderArmourFtzParser.new val_set, other_data, product_cache unless val_set.empty?
      true #don't return garbage value from previous line
    end
    
    #constructor, don't use, instead use static parse method
    def initialize rows, other_data, product_cache
      @other_data = other_data
      @product_cache = product_cache
      init_custom_definitions
      process_entry rows
      process_shipment rows
    end


    private
    #find or create custom definitions required by the parser
    def init_custom_definitions
      @custom_definitions = {}
      OpenChain::UnderArmourReceivingParser::CUSTOM_DEFINITIONS.each do |k,v|
        @custom_definitions[k] = CustomDefinition.find_or_create_by_module_type_and_label(v[1],k,:data_type=>v[0])
      end
    end

    def process_shipment rows
      process_shipment_header rows.first
      @shipment.save!
      rows.each_with_index do |r,i| 
        line = process_shipment_line r
        line.save!
        puts "Saving shipment line #{i}" if i.modulo(100)==0
      end
      process_shipment_custom_values rows
    end

    def process_shipment_header row
      v = Company.find_or_create_by_system_code_and_vendor(GENERIC_UA_VENDOR_NAME,true,:name=>GENERIC_UA_VENDOR_NAME)
      @shipment = Shipment.find_or_create_by_reference_and_vendor_id row[1], v
    end

    def process_shipment_line row
      prod = product(row[3])
      @shipment_row ||= 1
      @shipment_lines ||= {}
      sd = @shipment_lines[shipment_row_uid(row)]
      if sd.nil?
        sd = @shipment_lines[shipment_row_uid(row)] = @shipment.shipment_lines.build(:line_number=>@shipment_row,:product=>prod)
        @shipment_row += 1
      end
      sd.quantity = row[5]
      sd
    end

    def shipment_row_uid row
      "#{row[3]}-#{row[4]}-#{row[6]}-#{row[2]}"
    end

    def process_shipment_custom_values rows
      @cd_del ||= CustomDefinition.find_by_label "Delivery Date"
      @cd_po ||= CustomDefinition.find_by_label "PO Number"
      @cd_sz ||= CustomDefinition.find_by_label "Size"
      @cd_co ||= CustomDefinition.find_by_label "Country of Origin"
      cv = @shipment.get_custom_value @cd_del 
      cv.value = @other_data[:entry_date]
      cv.save!
      rows.each_with_index do |r,i|
        sd = @shipment_lines[shipment_row_uid(r)]
        v = sd.get_custom_value @cd_po
        v.value = numeric_to_string r[2]
        v.save!
        v = sd.get_custom_value @cd_sz
        v.value = numeric_to_string r[4]
        v.save!
        v = sd.get_custom_value @cd_co
        v.value = r[6]
        v.save!
        puts "Saving custom values for line #{i}" if i.modulo(100)==0
      end
    end

    def product uid
      p = @product_cache[uid]
      if p.blank?
        p = Product.find_or_create_by_unique_identifier(uid,:vendor_id=>@shipment.vendor_id)
        @product_cache[uid] = p
      end
      p
    end

    def process_entry rows
      process_entry_header rows.first
      puts "Saving Entry Header #{@entry.entry_number}"
      rows.each_with_index do |r|
        line = process_entry_detail r
        puts "Saving Entry Line: #{@entry_line_number}" if @entry_line_number.modulo(100)==0
      end
      @entry.save!
    end

    def process_entry_header row
      c = Company.find_or_create_by_name_and_importer IMPORTER_NAME, true
      entry_number = row[1].gsub('-','')
      @entry = Entry.find_by_entry_number_and_importer_id entry_number 
      @entry ||= Entry.new(:source_system=>SOURCE_CODE,:importer_id=>c.id,:import_country=>Country.find_by_iso_code('US'),:entry_number=>entry_number)
      @entry.commercial_invoices.destroy_all
      @invoice = @entry.commercial_invoices.build(:invoice_number=>'N/A') unless @invoice
      @entry.entry_port_code = @other_data[:port_code]
      @entry.arrival_date = @other_data[:entry_date]
      @entry.total_invoiced_value = @other_data[:entered_value]
      @entry.total_duty = @other_data[:box_37_value]
      @entry.total_duty_direct = @other_data[:box_40_value]
      @entry.merchandise_description = "WEARING APPAREL, FOOTWEAR"
      @entry.mpf = @other_data[:mpf]
    end
    def process_entry_detail row
      @entry_line_number ||= 1
      line = @invoice.commercial_invoice_lines.build(:line_number=>@entry_line_number)
      line.part_number = row[3].strip
      line.po_number = numeric_to_string row[2]
      line.quantity = row[5]
      tar = line.commercial_invoice_tariffs.build
      tar.duty_amount = row[9]
      tar.classification_qty_1 = row[5]
      tar.classification_uom_1 = "EA"
      tar.hts_code = numeric_to_string row[7]
      tar.entered_value = row[8]
      line
    end

    def numeric_to_string n
      r = n.to_s
      r = r[0,r.size-2] if r.ends_with? ".0"
      r
    end
  end
end
