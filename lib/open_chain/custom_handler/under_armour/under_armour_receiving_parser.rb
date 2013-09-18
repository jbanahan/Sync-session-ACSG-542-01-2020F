require 'open_chain/xl_client'
module OpenChain; module CustomHandler; module UnderArmour
  class UnderArmourReceivingParser
    include OpenChain::CustomHandler::UnderArmour::UnderArmourCustomDefinitionSupport

    #These custom definitions will be automatically created in if they don't already exist
    CUSTOM_DEFINITIONS = {
      'Country of Origin'=>[:coo,3],
      'PO Number'=>[:po,5],
      'Size'=>[:size,11],
      'Delivery Date'=>[:del_date,7],
      'Color'=>[:color,9]
    }

    def self.validate_s3 s3_path
      r = []
      headings = {0=>'Vendor',2=>'Stock Category',3=>'Ship From Country',5=>'PO Number',6=>'IBD Number',7=>'Delivery Date',8=>'AGI Date',9=>'Material',11=>'Grid Value',12=>'Plant',
      14=>'Company Code',16=>'PO Doc Type',17=>'Delivery Qty',18=>'AFS Net Price',19=>'Delivery Value'}
      client = OpenChain::XLClient.new s3_path
      row = client.get_row 0, 0 
      val_hash = {}
      row.each do |cell|
        val_hash[cell['position']['column']] = cell['cell']['value']
      end
      headings.each do |k,v|
        if val_hash[k].blank?
          r << "Heading at position #{k} should be #{v} and was blank."
        elsif val_hash[k]!=v
          r << "Heading at position #{k} should be #{v} and was #{val_hash[k]}."
        end
      end
      r
    end

    # parse file from s3
    def self.parse_s3 s3_path, first_row=1
      product_cache = {}
      client = OpenChain::XLClient.new s3_path
      last_row_number = client.last_row_number 0
      val_set = []
      last_ibd_number = nil
      (first_row..last_row_number).each do |row_num|
        row = client.get_row 0, row_num
        val_hash = {}
        row.each do |cell|
          val_hash[cell['position']['column']] = cell['cell']['value']
        end
        ibd_number = val_hash[6]
        raise "Row #{row_num} does not have IBD number." unless ibd_number
        if ibd_number != last_ibd_number && !val_set.empty?
          UnderArmourReceivingParser.new val_set, product_cache
          val_set = []
        end
        last_ibd_number = ibd_number
        val_set << val_hash
      end
      UnderArmourReceivingParser.new val_set, product_cache unless val_set.empty?
      true #don't return garbage value from previous line
    end

    # DO NOT CALL DIRECLTY, USE CLASS LEVEL parse_s3 method
    def initialize val_set, product_cache
      @product_cache = product_cache
      init_custom_definitions
      process_header val_set.first
      @row_num = 1
      @shipment.shipment_lines.each {|sl| @row_num = sl.line_number + 1 if sl.line_number >= @row_num}
      val_set.each {|row| process_detail row}
      @shipment.save!
      val_set.each_with_index {|row,i| process_custom_values row, (i+1)}
    end
    
    private
    #find or create custom definitions required by the parser
    def init_custom_definitions
      @custom_definitions = {}
      cdefs = self.class.prep_custom_definitions(CUSTOM_DEFINITIONS.values.collect{|v| v[0]})
      CUSTOM_DEFINITIONS.each do |k,v|
        @custom_definitions[k] = cdefs[v[0]] 
      end
    end
    def process_header row
      sys_code = trim_numeric row[0]
      ref = trim_numeric row[6]
      vendor = Company.find_or_create_by_system_code_and_vendor(sys_code,true,:name=>row[1])
      @shipment = Shipment.find_by_reference_and_vendor_id ref, vendor.id
      @shipment = Shipment.new(:reference=>ref,:vendor=>vendor,:importer=>Company.find_by_importer(true)) unless @shipment
    end

    def process_detail row
      @row_num ||= 1
      @shipment_lines ||= {}
      p = row_uid row #style-color-size
      sd = @shipment_lines[p]
      if sd.nil?
        sd = @shipment.shipment_lines.build(:line_number=>@row_num,:product=>product(row))
        @shipment_lines[p] = sd
        @row_num += 1
      end
      sd.quantity = row[17]
    end

    def process_custom_values row, index
      prod = product(row)
      line = @shipment_lines[row_uid(row)] 
      CUSTOM_DEFINITIONS.each do |k,v|
        base = (k=='Delivery Date' ? @shipment : line)
        cv = base.get_custom_value @custom_definitions[k]
        val = nil
        case v[0]
        when :del_date
          val = row[7]
        when :color
          val = row[9].split('-').last
        else
          val = trim_numeric(row[v[1]])
        end
        cv.value = val 
        cv.save!
      end
    end

    def row_uid row
      # style-color-size-po
      "#{row[9]}-#{row[11]}-#{trim_numeric row[5]}"
    end

    def product row
      uid = row[9].split('-').first
      p = @product_cache[uid]
      if p.blank?
        p = Product.find_or_create_by_unique_identifier(uid,:vendor_id=>@shipment.vendor_id)
        @product_cache[uid] = p
      end
      p
    end

    def trim_numeric val
      !val.blank? && val.to_s.ends_with?('.0') ? val.to_s[0,val.to_s.size-2] : val
    end
  end
end; end; end
