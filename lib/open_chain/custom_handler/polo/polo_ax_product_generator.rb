require 'open_chain/custom_handler/product_generator'
require 'open_chain/custom_handler/polo/polo_custom_definition_support'


module OpenChain; module CustomHandler; module Polo; class PoloAxProductGenerator < OpenChain::CustomHandler::ProductGenerator
  include OpenChain::CustomHandler::Polo::PoloCustomDefinitionSupport

  def self.run_schedulable opts = {}
    self.new(opts).generate
  end

  def auto_confirm?
    false
  end

  def max_results
    300
  end

  def sync_code
    "AX"
  end

  def generate
    count = nil
    begin
      file = sync_csv
      ftp_file file if (count = self.row_count) > 0
    end while count > 0
  end

  def sync_csv
    super(csv_opts: {force_quotes: true})
  end

  def ftp_credentials
    folder = MasterSetup.get.production? ? "ax_products" : "ax_products_test"
    connect_vfitrack_net("to_ecs/#{folder}", "ax_export_#{Time.zone.now.strftime("%Y%m%d%H%M%S%L")}.csv")
  end

  def preprocess_row row, opts = {}
    product = Product.where(id: opts[:product_id]).
        includes(:custom_values, {classifications: [:custom_values, :tariff_records, :country]}).
        first

    rows = []
    if product
      classifications_sent = false

      # Sort the classifications by ISO Code to keep the order consistent
      Array.wrap(product.classifications).sort_by {|c| c.country.try(:iso_code) }.each do |classification|
        classification.tariff_records.each do |tariff_record|
          rows << create_file_row(product, classification, tariff_record)
          classifications_sent = true
        end
      end

      # If the product didn't have classifications, we'll have to send a line without any country data.
      if !classifications_sent
        rows << create_file_row(product, nil, nil)
      end
    end

    rows
  end

  def create_file_row product, classification, tariff_record
    row = []
    class_data = classification_data(classification, tariff_record)
    dimensions = dimensions_data(product)

    row << product.unique_identifier
    row << class_data[:country]
    row << boolean(class_data[:mp_flag])
    row << class_data[:hts_1]
    row << class_data[:hts_2]
    row << class_data[:hts_3]
    row << dimensions[:length]
    row << dimensions[:width]
    row << dimensions[:height]
    row << handle_footwear_upper_fabric_type(product, 1)
    row << product.custom_value(cdefs[:fabric_1])
    row << product.custom_value(cdefs[:fabric_percent_1])
    row << handle_footwear_upper_fabric_type(product, 2)
    row << product.custom_value(cdefs[:fabric_2])
    row << product.custom_value(cdefs[:fabric_percent_2])
    row << handle_footwear_upper_fabric_type(product, 3)
    row << product.custom_value(cdefs[:fabric_3])
    row << product.custom_value(cdefs[:fabric_percent_3])
    row << handle_footwear_upper_fabric_type(product, 4)
    row << product.custom_value(cdefs[:fabric_4])
    row << product.custom_value(cdefs[:fabric_percent_4])
    row << handle_footwear_upper_fabric_type(product, 5)
    row << product.custom_value(cdefs[:fabric_5])
    row << product.custom_value(cdefs[:fabric_percent_5])
    row << handle_footwear_upper_fabric_type(product, 6)
    row << product.custom_value(cdefs[:fabric_6])
    row << product.custom_value(cdefs[:fabric_percent_6])
    row << handle_footwear_upper_fabric_type(product, 7)
    row << product.custom_value(cdefs[:fabric_7])
    row << product.custom_value(cdefs[:fabric_percent_7])
    row << handle_footwear_upper_fabric_type(product, 8)
    row << product.custom_value(cdefs[:fabric_8])
    row << product.custom_value(cdefs[:fabric_percent_8])
    row << handle_footwear_upper_fabric_type(product, 9)
    row << product.custom_value(cdefs[:fabric_9])
    row << product.custom_value(cdefs[:fabric_percent_9])
    row << handle_footwear_upper_fabric_type(product, 10)
    row << product.custom_value(cdefs[:fabric_10])
    row << product.custom_value(cdefs[:fabric_percent_10])
    row << handle_footwear_upper_fabric_type(product, 11)
    row << product.custom_value(cdefs[:fabric_11])
    row << product.custom_value(cdefs[:fabric_percent_11])
    row << handle_footwear_upper_fabric_type(product, 12)
    row << product.custom_value(cdefs[:fabric_12])
    row << product.custom_value(cdefs[:fabric_percent_12])
    row << handle_footwear_upper_fabric_type(product, 13)
    row << product.custom_value(cdefs[:fabric_13])
    row << product.custom_value(cdefs[:fabric_percent_13])
    row << handle_footwear_upper_fabric_type(product, 14)
    row << product.custom_value(cdefs[:fabric_14])
    row << product.custom_value(cdefs[:fabric_percent_14])
    row << handle_footwear_upper_fabric_type(product, 15)
    row << product.custom_value(cdefs[:fabric_15])
    row << product.custom_value(cdefs[:fabric_percent_15])
    row << product.custom_value(cdefs[:knit_woven])
    row << product.custom_value(cdefs[:fiber_content])
    row << product.custom_value(cdefs[:common_name_1])
    row << product.custom_value(cdefs[:common_name_2])
    row << product.custom_value(cdefs[:common_name_3])
    row << product.custom_value(cdefs[:scientific_name_1])
    row << product.custom_value(cdefs[:scientific_name_2])
    row << product.custom_value(cdefs[:scientific_name_3])
    row << product.custom_value(cdefs[:fish_wildlife_origin_1])
    row << product.custom_value(cdefs[:fish_wildlife_origin_2])
    row << product.custom_value(cdefs[:fish_wildlife_origin_3])
    row << product.custom_value(cdefs[:fish_wildlife_source_1])
    row << product.custom_value(cdefs[:fish_wildlife_source_2])
    row << product.custom_value(cdefs[:fish_wildlife_source_3])
    row << product.custom_value(cdefs[:origin_wildlife])
    row << boolean(product.custom_value(cdefs[:semi_precious]))
    row << product.custom_value(cdefs[:semi_precious_type])
    row << boolean(product.custom_value(cdefs[:cites]))
    row << boolean(product.custom_value(cdefs[:fish_wildlife]))
    row << product.custom_value(cdefs[:msl_gcc_desc])
    row << product.custom_value(cdefs[:gcc_description_2])
    row << product.custom_value(cdefs[:gcc_description_3])
    row << boolean(product.custom_value(cdefs[:non_textile]))
    row << boolean(product.custom_value(cdefs[:meets_down_requirments]))
    row << class_data[:set_type]

    # Technically, RL only asked for newlines to be stripped from the fiber content, but
    # I know that their parser can't handle newlines at all for any field so I'm just
    # removing them across the board.
    row.each do |r|
      r.gsub!("\n", " ") if r.is_a?(String)
    end

    convert_array_to_results_hash(row)
  end

  def classification_data classification, hts
    data = {}
    if !classification.nil?
      data[:country] = classification.try(:country).try(:iso_code)
      hts = hts
      data[:set_type] = classification.custom_value(cdefs[:set_type])

      if data[:country].to_s.strip.upcase == "TW"
        data[:hts_1] = hts.try(:hts_1)
        data[:hts_2] = hts.try(:hts_2)
        data[:hts_3] = hts.try(:hts_3)
        # We're conciously not sending hts formatted numbers for taiwan, since they're more than 10 digits long
        data[:mp_flag] = taiwan_mp(data[:hts_1], data[:hts_2], data[:hts_3])
      else
        data[:hts_1] = hts.try(:hts_1).try(:hts_format)
        data[:hts_2] = hts.try(:hts_2).try(:hts_format)
        data[:hts_3] = hts.try(:hts_3).try(:hts_format)
      end  
    end
    data
  end

  def handle_footwear_upper_fabric_type product, index
    # For products that had fiber analysis run on them prior to this project going live, RL
    # required that we change the fabric_type on the Upper portion of the footwear from "Upper" to "Outer" 
    # for footwear due to some weirdness in MSL+.  
    # We need to now retain "Upper", which is what the fiber content parser is doing,
    # however, we also need to deal with legacy products.  To do that, we're going to change "Outer" to "Upper"
    # if (and only if) there's another fabric_type_x value that is "Sole" (since all footwear that had 
    # Upper changed to Outer will have a "Sole" fabric type).
    fabric_type = product.custom_value(cdefs["fabric_type_#{index}".to_sym])
    if fabric_type.to_s.upcase == "OUTER"
      ((index + 1)..15).each do |x|
        fabric_type_x = product.custom_value(cdefs["fabric_type_#{x}".to_sym])
        break if fabric_type_x.nil?

        if fabric_type_x.to_s.upcase == "SOLE"
          fabric_type = "Upper"
          break
        end
      end
    end

    return fabric_type
  end

  def boolean v
    ["true", "Y", "1"].include?(v.to_s) ? "1" : "0"
  end

  def dimensions_data product
    # The product will have either cms or inches...AX only accepts cms, so we need to convert inches to cms if 
    # the product has in.  Product will only have one or the other, not both.
    data = {length: nil, width: nil, height: nil}

    data[:length] = product.custom_value(cdefs[:length_cm])
    data[:width] = product.custom_value(cdefs[:width_cm])
    data[:height] = product.custom_value(cdefs[:height_cm])

    return data if data[:length].try(:nonzero?) || data[:width].try(:nonzero?) || data[:height].try(:nonzero?)

    data[:length] = convert_to_centimeters product.custom_value(cdefs[:length_in])
    data[:width] = convert_to_centimeters product.custom_value(cdefs[:width_in])
    data[:height] = convert_to_centimeters product.custom_value(cdefs[:height_in])

    data
  end

  def convert_to_centimeters inches
    return nil unless inches
    (inches * BigDecimal("2.54")).round(2)
  end

  def taiwan_mp hts_1, hts_2, hts_3
    # There's currently only 345 records in the TW tariff that have MP1 regulations, so we can just load them into a map
    # rather than looking them up for every single product on the feed.
    [hts_1, hts_2, hts_3].any? {|v| taiwan_mp_hts_codes.include? v }
  end

  def taiwan_mp_hts_codes
    @mp_map ||= Set.new(OfficialTariff.
            where("country_id = (SELECT id FROM countries where iso_code = 'TW')").
            where("import_regulations like ?", "%MP1%").pluck :hts_code)
  end

  def query
    # We're just going to look up the products individually during the preprocess row phase...there's so many custom definitions involved
    # that the query to include them all will be a nightmare.  Plus, the MSL feed, which this is replacing was already 
    # handling the products 1 by 1 so this shouldn't be any more load than that was causing.
    q = "SELECT DISTINCT products.id
FROM products
INNER JOIN classifications c on c.product_id = products.id 
INNER JOIN tariff_records t on t.classification_id = c.id AND t.hts_1 <> ''
INNER JOIN custom_values ax_export ON ax_export.customizable_id = products.id AND ax_export.customizable_type = 'Product' AND ax_export.custom_definition_id = #{cdefs[:ax_export_status].id} AND ax_export.string_value = 'Exported'
INNER JOIN custom_values fabric_1 on fabric_1.customizable_id = products.id AND fabric_1.customizable_type = 'Product' AND fabric_1.custom_definition_id = #{cdefs[:fabric_1].id} AND fabric_1.string_value <> ''
INNER JOIN custom_values fabric_type_1 on fabric_type_1.customizable_id = products.id AND fabric_type_1.customizable_type = 'Product' AND fabric_type_1.custom_definition_id = #{cdefs[:fabric_type_1].id} AND fabric_type_1.string_value <> ''
INNER JOIN custom_values fabric_percent_1 on fabric_percent_1.customizable_id = products.id AND fabric_percent_1.customizable_type = 'Product' AND fabric_percent_1.custom_definition_id = #{cdefs[:fabric_percent_1].id} AND fabric_percent_1.decimal_value > 0
INNER JOIN custom_values fiber_content on fiber_content.customizable_id = products.id AND fiber_content.customizable_type = 'Product' AND fiber_content.custom_definition_id = #{cdefs[:fiber_content].id} AND fiber_content.string_value <> ''
INNER JOIN custom_values msl_gcc_desc on msl_gcc_desc.customizable_id = products.id AND msl_gcc_desc.customizable_type = 'Product' AND msl_gcc_desc.custom_definition_id = #{cdefs[:msl_gcc_desc].id} AND msl_gcc_desc.string_value <> ''
INNER JOIN custom_values non_textile on non_textile.customizable_id = products.id AND non_textile.customizable_type = 'Product' AND non_textile.custom_definition_id = #{cdefs[:non_textile].id} AND non_textile.string_value <> ''
"
    if self.custom_where.blank?
      q << " #{Product.join_clause_for_need_sync(sync_code)}
WHERE #{Product.where_clause_for_need_sync(sent_at_or_before: Time.zone.now - 24.hours)}
"
    else
      q << self.custom_where
    end

    q << " ORDER BY products.id ASC LIMIT #{max_results}"
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions([
      :msl_gcc_desc, :gcc_description_2, :gcc_description_3, :length_cm, :width_cm, :height_cm, :length_in, :width_in, :height_in,
      :fabric_1, :fabric_2, :fabric_3, :fabric_4, :fabric_5, :fabric_6, :fabric_7, :fabric_8, :fabric_9, :fabric_10, :fabric_11, :fabric_12,
      :fabric_13, :fabric_14, :fabric_15, :fabric_type_1, :fabric_type_2, :fabric_type_3, :fabric_type_4, :fabric_type_5, :fabric_type_6, 
      :fabric_type_7, :fabric_type_8, :fabric_type_9, :fabric_type_10, :fabric_type_11, :fabric_type_12, :fabric_type_13, :fabric_type_14, 
      :fabric_type_15, :fabric_percent_1, :fabric_percent_2, :fabric_percent_3, :fabric_percent_4, :fabric_percent_5, :fabric_percent_6, 
      :fabric_percent_7, :fabric_percent_8, :fabric_percent_9, :fabric_percent_10, :fabric_percent_11, :fabric_percent_12, :fabric_percent_13, 
      :fabric_percent_14, :fabric_percent_15, :knit_woven, :fiber_content, :common_name_1, :common_name_2, :common_name_3, :scientific_name_1,
      :scientific_name_2, :scientific_name_3, :fish_wildlife_origin_1, :fish_wildlife_origin_2, :fish_wildlife_origin_3, 
      :fish_wildlife_source_1, :fish_wildlife_source_2, :fish_wildlife_source_3, :origin_wildlife, :semi_precious, :semi_precious_type,
      :cites, :fish_wildlife, :meets_down_requirments, :non_textile, :set_type, :ax_export_status
    ])
  end

  def preprocess_header_row row
    header_fields = [
      "GFE+ Material Number", 
      "Country", 
      "MP1 Flag", 
      "HTS Number 1", 
      "HTS Number 2", 
      "HTS Number 3", 
      "Length CM", 
      "Width CM", 
      "Height CM", 
      "Fabric Type 1", 
      "Fabric 1", 
      "Fabric 1%", 
      "Fabric Type 2", 
      "Fabric 2", 
      "Fabric 2%", 
      "Fabric Type 3", 
      "Fabric 3", 
      "Fabric 3%", 
      "Fabric Type 4", 
      "Fabric 4", 
      "Fabric 4%", 
      "Fabric Type 5", 
      "Fabric 5", 
      "Fabric 5%", 
      "Fabric Type 6", 
      "Fabric 6", 
      "Fabric 6%", 
      "Fabric Type 7", 
      "Fabric 7", 
      "Fabric 7%", 
      "Fabric Type 8", 
      "Fabric 8", 
      "Fabric 8%", 
      "Fabric Type 9", 
      "Fabric 9", 
      "Fabric 9%", 
      "Fabric Type 10", 
      "Fabric 10", 
      "Fabric 10%", 
      "Fabric Type 11", 
      "Fabric 11", 
      "Fabric 11%", 
      "Fabric Type12", 
      "Fabric 12", 
      "Fabric 12%", 
      "Fabric Type 13", 
      "Fabric 13", 
      "Fabric 13%", 
      "Fabric Type 4", 
      "Fabric 14", 
      "Fabric 14%", 
      "Fabric Type 15", 
      "Fabric 15", 
      "Fabric 15%", 
      "Knit Woven", 
      "Fiber Content", 
      "Common Name 1", 
      "Common Name 2", 
      "Common Name 3", 
      "Scientific Name 1", 
      "Scientific Name 2", 
      "Scientific Name 3", 
      "F&W Origin 1", 
      "F&W Origin 2", 
      "F&W Origin 3", 
      "F&W Source 1", 
      "F&W Source 2", 
      "F&W Source 3", 
      "Origin of Wildlife", 
      "Semi Precious", 
      "Semi Precious Type", 
      "Cites Flag", 
      "Fish & Wildlife Flag", 
      "GCC Description", 
      "GCC Description 2", 
      "GCC Description 3", 
      "Non-Textile Flag", 
      "Down Indicator Flag", 
      "Set Item Indicator Flag"
    ]

    [convert_array_to_results_hash(header_fields)]
  end

end; end; end; end