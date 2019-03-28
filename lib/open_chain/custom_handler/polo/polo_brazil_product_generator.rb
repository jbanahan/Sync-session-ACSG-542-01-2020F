require 'open_chain/custom_handler/ack_file_handler'
require 'open_chain/custom_handler/polo/polo_custom_definition_support'

module OpenChain; module CustomHandler; module Polo; class PoloBrazilProductGenerator
  include OpenChain::CustomHandler::Polo::PoloCustomDefinitionSupport
  include ActionView::Helpers::NumberHelper

  # :env=>:qa will put files in _test_to_RL_Brazil instead of _to_RL_Brazil
  def initialize opts={}
    o = HashWithIndifferentAccess.new(opts)
    @env = o[:env].to_sym if o[:env]
  end

  def self.run_schedulable opts
    g = self.new(opts)
    g.products_to_send.find_in_batches do |prods|
      g.send_and_delete_sync_file g.generate_outbound_sync_file prods
    end
  end

  # find the products that need to be sent to MSL+ (they have MSL+ Receive Dates and need sync)
  def products_to_send
    send_countries = send_classification_countries
    init_outbound_custom_definitions
    Product.select("distinct products.*").need_sync("Brazil").
      joins("INNER JOIN classifications c ON c.product_id = products.id AND c.country_id IN (#{send_countries.join(",")})")
  end

  # Generate the file with data that needs to be sent back to MSL+
  def generate_outbound_sync_file products
    file = Tempfile.new(['msl_outbound','.csv'])
    headers = ["Style", "Country", "MP1 Flag", "HTS 1", "HTS 2", "HTS 3", "Length", "Width", "Height"]
    (1..15).each do |x|
      headers << "Fabric Type - #{x}"
      headers << "Fabric - #{x}"
      headers << "Fabric % - #{x}"
    end
    headers.push *["Knit / Woven?", "Fiber Content %s", "Common Name 1", "Common Name 2", "Common Name 3",
      "Scientific Name 1", "Scientific Name 2", "Scientific Name 3", "F&W Origin 1", "F&W Origin 2", "F&W Origin 3",
      "F&W Source 1", "F&W Source 2", "F&W Source 3", "Origin of Wildlife", "Semi-Precious", "Type of Semi-Precious", "CITES", "Fish & Wildlife"]

    file << headers.to_csv(col_sep: '|')
    send_countries = send_classification_countries
    init_outbound_custom_definitions
    products.each do |p|
      line_count = 0
      classifications = p.classifications.includes(:country, :tariff_records).where("classifications.country_id IN (?)",send_countries)
      classifications.each do |cl|
        iso = cl.country.iso_code
        cl.tariff_records.order("line_number ASC").each do |tr|
          file << outbound_file_content(p, tr, iso).to_csv(col_sep: '|')
          line_count += 1
        end

        # Send blank tariff data if we haven't sent anything for this classification country
        if line_count == 0
          file << outbound_file_content(p, nil, iso).to_csv(col_sep: '|')
        end
      end

      if line_count == 0
        file << outbound_file_content(p, nil, nil).to_csv(col_sep: '|')
      end

      sr = p.sync_records.find_or_initialize_by_trading_partner("Brazil")
      sr.update_attributes(:sent_at=>Time.now, confirmed_at: (Time.now + 1.minute))
    end
    file.flush
    file
  end

  # Send the file created by `generate_outbound_sync_file`
  def send_and_delete_sync_file local_file, send_time=Time.now #only override send_time for test case
    send_file local_file, "ChainIO_HTSExport_#{send_time.strftime('%Y%m%d%H%M%S')}.csv"
    File.delete local_file
  end

  def send_file local_file, destination_file_name
    FtpSender.send_file("connect.vfitrack.net",'polo','pZZ117',local_file,{:folder=>(@env==:qa ? '/_test_to_RL_Brazil' : '/_to_RL_Brazil'),:remote_file_name=>destination_file_name})
  end

  private

    def send_classification_countries
      @send_countries ||= Country.where("iso_code IN (?)",['IT']).pluck :id
    end

    def hts_value hts, country_iso
      h = hts.nil? ? "" : hts
      country_iso=="TW" ? h : h.hts_format
    end
    def mp1_value tariff_record, country_iso
      return "" unless tariff_record && country_iso == 'TW'
      found = OfficialTariff.
        where("hts_code IN (?)",[tariff_record.hts_1,tariff_record.hts_2,tariff_record.hts_3].compact).
        where("country_id = (SELECT ID from countries where iso_code = \"TW\")").
        where("import_regulations like \"%MP1%\"").count
      found > 0 ? "true" : ""
    end

    def init_outbound_custom_definitions
      if @out_cdefs.nil?
        cdefs = [:length_cm, :width_cm, :height_cm, :msl_receive_date, :csm_numbers]
        @fiber_defs = []
        (1..15).each do |x|
          @fiber_defs << "fabric_type_#{x}".to_sym
          @fiber_defs << "fabric_#{x}".to_sym
          @fiber_defs << "fabric_percent_#{x}".to_sym
        end

        cdefs.push *@fiber_defs

        cdefs.push :material_group, :fiber_content, :common_name_1, :common_name_2, :common_name_3, :scientific_name_1, :scientific_name_2, :scientific_name_3,
                    :fish_wildlife_origin_1, :fish_wildlife_origin_2, :fish_wildlife_origin_3, :fish_wildlife_source_1, :fish_wildlife_source_2, :fish_wildlife_source_3,
                    :origin_wildlife, :semi_precious, :semi_precious_type, :cites, :fish_wildlife, :bartho_customer_id, :msl_fiber_failure, :msl_us_class

        @out_cdefs = self.class.prep_custom_definitions cdefs
      end
      @out_cdefs
    end

    def outbound_file_content p, tr, iso
      # Be careful in here, the tariff record (tr) and ISO CAN be nil now
      p.freeze_custom_values

      # RL wants the MSL system to receive product level data, BUT the MSL system can't receive data if it doesn't have a country code, SO
      # we're defaulting to IT when there is no classification for the product.

      file = [p.unique_identifier, (iso.presence || "IT"), mp1_value(tr,iso), hts_value(tr.try(:hts_1), iso), hts_value(tr.try(:hts_2), iso), hts_value(tr.try(:hts_3), iso)]
      file.push *get_custom_values(p, :length_cm, :width_cm, :height_cm)

      if skip_fiber_fields? p
        45.times {file << nil}
      else
        file.push *get_custom_values(p, *@fiber_defs)
      end

      file.push *get_custom_values(p, :material_group, :fiber_content, :common_name_1, :common_name_2, :common_name_3, :scientific_name_1, :scientific_name_2, :scientific_name_3,
                    :fish_wildlife_origin_1, :fish_wildlife_origin_2, :fish_wildlife_origin_3, :fish_wildlife_source_1, :fish_wildlife_source_2, :fish_wildlife_source_3,
                    :origin_wildlife, :semi_precious, :semi_precious_type, :cites, :fish_wildlife)

      # Change all newlines to spaces
      file.map {|v| v.is_a?(String) ? v.gsub(/\r?\n/, " ") : v}
    end

    def skip_fiber_fields? p
       # RL wants to prevent certain divisions from sending fiber content values at this time.
      # Mostly due to the fiber content from these divisions being garbage
      barthco_id = p.get_custom_value(@out_cdefs[:bartho_customer_id]).value.to_s.strip

       # Don't send fiber fields if the fiber parser process was unable to read them either
      msl_fiber_failure = p.get_custom_value(@out_cdefs[:msl_fiber_failure]).value == true
      msl_us_class = p.get_custom_value(@out_cdefs[:msl_us_class]).value
      us_class_blacklist = ["Bracelet", "Cuff link", "Cufflinks", "Earring", "Earrings", "Jewelry", "Key Chain", "Key Fob", "Keyfob", "Necklace", "Ring"]
      msl_fiber_failure || barthco_id.blank? || ["48650", "47080"].include?(barthco_id) || us_class_blacklist.include?(msl_us_class)
    end

    def get_custom_values product, *defs
      defs.map do |d|
        value = product.get_custom_value(@out_cdefs[d]).value

        # This is pretty much solely for formatting the Fiber Percentage fields, but there's no other fields that are
        # decimal values that will be more than 2 decimal places, so it works here in the main method for getting the custom values
        if value.is_a?(Numeric)
          value = number_with_precision(value, precision: 2, strip_insignificant_zeros: true)
        end

        value
      end
    end
end; end; end; end
