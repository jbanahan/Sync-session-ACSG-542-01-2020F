require 'open_chain/xl_client'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; module Crocs
  class CrocsReceivingParser
    include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
    #validates that the file headings are good
    #returns empty array if good, or error messages in array if bad
    def self.validate_s3 s3_path
      r = []
      expected = [
        'SHPMT_NBR',
        'PO_NBR',
        'SKU_BRCD',
        'STYLE',
        'COLOR',
        'SIZ',
        'SKU_DESC',
        'CNTRY_OF_ORGN',
        'UNITS_RCVD',
        'RCVD_DATE'
      ]
      actual = OpenChain::XLClient.new(s3_path).get_row_values 0, 0
      expected.each_with_index do |e,i|
        if actual[i].blank?
          r << "Heading at position #{i+1} should be #{e} and was blank."
          next
        elsif actual[i]!=e
          r << "Heading at position #{i+1} should be #{e} and was #{actual[i]}."
        end
      end
      r
    end

    # returns array with earliest & latest received dates processed across all rows
    def self.parse_s3 s3_path
      v = validate_s3 s3_path
      raise "Validation errors: #{v.join(' ')}" unless v.empty? 
      shipment_rows = []
      last_shipment_number = nil
      earliest_date = nil 
      latest_date = nil 
      cursor = 0
      parser = self.new
      OpenChain::XLClient.new(s3_path).all_row_values(0) do |r|
        cursor += 1
        next if cursor == 1
        received_date = r[9].to_date
        earliest_date = received_date if earliest_date.nil? || received_date < earliest_date
        latest_date = received_date if latest_date.nil? || received_date > latest_date
        shipment_number = r.first
        if shipment_number!=last_shipment_number && !shipment_rows.blank?
          parser.parse_shipment shipment_rows
          shipment_rows = []
        end
        shipment_rows << r
        last_shipment_number = shipment_number
      end
      parser.parse_shipment shipment_rows unless shipment_rows.empty?
      [earliest_date,latest_date]
    end




    # don't call this, use the static methods
    def initialize
      @company = Company.with_customs_management_number('CROCS').first
      @vendor = Company.where(vendor:true,system_code:'CROCS-VENDOR').first_or_create!(name:'CROCS VENDOR')
      @defs = self.class.prep_custom_definitions [:shpln_po,:shpln_sku,:shpln_color,:shpln_size,:shpln_coo,:shpln_received_date,:shpln_desc]
      @part_cache = {}
    end
    def parse_shipment rows
      ship_num = "CROCS-#{rows.first.first}"
      Shipment.transaction do
        cvals = []
        shipment = Shipment.where(importer_id:@company.id,reference:ship_num).first_or_create!(vendor_id:@vendor.id)
        row_hash = {}
        rows.each do |r|
          r.each_with_index {|x,i| r[i] = clean_str x}
          key = "#{r[1]}-#{r[2]}-#{r[9]}-#{r[7]}"
          v = row_hash[key]
          if v
            v[8] += r[8]
          else
            row_hash[key] = r
          end
        end
        row_hash.values.each do |r|
#          raise "Duplicate receipts #{ship_num}, #{r[1]}, #{r[2]}, #{r[9]}, #{r[7]}" if record_exists? shipment, r[1], r[2], r[9], r[7]
          part_uid = "CROCS-#{r[3]}"
          product = @part_cache[part_uid]
          if product.nil?
            product = Product.where(importer_id:@company.id,unique_identifier:part_uid).first_or_create!
            @part_cache[part_uid] = product
          end
          sl = shipment.shipment_lines.create!(product:product,quantity:r[8])
          {shpln_po: 1, shpln_sku: 2, shpln_color: 4, shpln_size: 5, shpln_desc: 6, shpln_coo: 7, shpln_received_date: 9}.each do |d,pos|
            v =  CustomValue.new(customizable:sl,custom_definition:@defs[d])
            v.value = r[pos]
            cvals << v
          end
          CustomValue.batch_write! cvals
        end
      end
    end

    private 
    def record_exists? shipment, po, sku, received_date, coo
      r = ShipmentLine.joins("
        INNER JOIN custom_values p ON p.custom_definition_id = #{@defs[:shpln_po].id.to_i} AND p.customizable_id = shipment_lines.id AND p.string_value = #{ActiveRecord::Base.connection.quote(po)}
        INNER JOIN custom_values k ON k.custom_definition_id = #{@defs[:shpln_sku].id.to_i} AND k.customizable_id = shipment_lines.id AND k.string_value = #{ActiveRecord::Base.connection.quote(sku)}
        INNER JOIN custom_values r ON r.custom_definition_id = #{@defs[:shpln_received_date].id.to_i} AND r.customizable_id = shipment_lines.id AND r.date_value = #{ActiveRecord::Base.connection.quote('#{received_date.year}-#{received_date.month}-#{received_date.day}')}
        INNER JOIN custom_values c ON c.custom_definition_id = #{@defs[:shpln_coo].id.to_i} AND c.customizable_id = shipment_lines.id AND c.string_value = #{ActiveRecord::Base.connection.quote(coo)}
      ").where(shipment_id:shipment.id)
      !r.empty?
    end

    def clean_str s
      return s unless !s.nil? && s.is_a?(Numeric)
      return s.to_s[0,s.to_s.length-2] if s.to_s.match /\.0$/
      s
    end
  end
end; end; end
