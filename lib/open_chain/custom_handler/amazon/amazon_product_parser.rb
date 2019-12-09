require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/mutable_boolean'
require 'open_chain/custom_handler/amazon/amazon_product_parser_support'

module OpenChain; module CustomHandler; module Amazon; class AmazonProductParser
  include OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include OpenChain::CustomHandler::Amazon::AmazonProductParserSupport

  def self.parse data, opts = {}
    csv_data = CSV.parse(data)
    self.new.process_parts(csv_data, User.integration, opts[:key])
  end

  def process_parts csv, user, filename
    # The first thing we want to do is group all the lines together by part number.
    parts = group_parts(csv)
    parts.each_pair do |action_sku, lines|
      if action_sku[0] == "DELETE"
        delete_part(user, filename, lines)
      else
        process_part_lines(user, filename, lines)
      end
    end
  end

  def delete_part user, filename, lines
    # This is a little weird, we're actually going to create the part even if that part didn't exist
    # and all we're doing is marking it inactive.
    # This is because I want some record of actually receiving the delete
    find_or_create_product(lines.first) do |product|
      product.update! inactive: true
      # I don't want to log every single part that's inactivated...it's going to be a lot of messages and mostly pointless since
      # the product history itself will have this information.
      product.create_snapshot user, nil, filename
    end
  end

  def process_part_lines user, filename, lines
    find_or_create_product(lines.first) do |product|
      if set_product_data(product, lines)
        # I don't want to log every single part that's updated...it's going to be a lot of messages and mostly pointless since
        # the product history itself will have this information.
        product.create_snapshot user, nil, filename
      end
    end
  end

  def set_product_data product, lines
    first_line = lines.first
    changed = MutableBoolean.new false
    product.unit_of_measure = text(first_line[13])
    product.name = text(first_line[15])

    set_custom_value(product, :prod_part_number, changed, sku(first_line))
    set_custom_value(product, :prod_importer_style, changed, text(first_line[2]))
    set_custom_value(product, :prod_country_of_origin, changed, text(first_line[5]))
    add_values = extract_embedded_csv(text(first_line[19]))
    set_custom_value(product, :prod_add_case, changed, add_values[0])
    set_custom_value(product, :prod_add_case_2, changed, add_values[1])
    cvd_values = extract_embedded_csv(text(first_line[20]))
    set_custom_value(product, :prod_cvd_case, changed, cvd_values[0])
    set_custom_value(product, :prod_cvd_case_2, changed, cvd_values[1])

    if product.changed? || changed.value
      product.save!
    end

    classification_updated, classification = set_classification_data(product, first_line)
    tariff_updated = set_tariff_data(classification, lines)
    
    manufacturer_updated = set_manufacturer_data(product, first_line)

    product.changed? || changed.value || classification_updated || tariff_updated || manufacturer_updated
  end

  def set_classification_data product, line
    # This is going to indicate to us which country to set the Tariff number under
    changed = MutableBoolean.new false

    classification_country = country(text(line[4]))
    classification = product.classifications.find {|c| c.country_id == classification_country.id }
    new_classification = false
    if classification.nil?
      classification = product.classifications.build country_id: classification_country.id
      new_classification = true
    end

    set_custom_value(classification, :class_binding_ruling_number, changed, text(line[16]))
    set_custom_value(classification, :class_classification_notes, changed, text(line[17]))

    update = changed.value || new_classification

    if update
      classification.save!
    end

    [update, classification]
  end

  def set_tariff_data classification, lines
    # The reason we capture multiple lines is because there's potentially X # of tariff numbers to add / update
    # We're going to pretty much assume that the tariff numbers should be ordered based on the ordering of the file lines
    hts_numbers = lines.map {|l| text(l[18]) }.compact

    tariff_changed = false
    hts_numbers.each_with_index do |hts_number, index|
      t = classification.tariff_records.find {|t| t.line_number == (index + 1) }  
      if t.nil?
        t = classification.tariff_records.build line_number: (index + 1)
      end
      t.hts_1 = hts_number
      if t.changed?
        t.save!
        tariff_changed = true
      end
    end
    
    classification.tariff_records.each do |t|
      if t.line_number > hts_numbers.length 
        t.destroy
        tariff_changed = true
      end
    end

    tariff_changed
  end

  def sku row
    text(row[3])
  end

  def header_row? row
    row[0].to_s.match?(/Data-Type/i)
  end

  def parts_key row
    [row[0].to_s.strip.upcase, sku(row)]
  end

  def ior row
    text(row[1])
  end

  def cdefs 
    @cdefs ||= self.class.prep_custom_definitions [:prod_part_number, :prod_importer_style, :prod_country_of_origin, :prod_add_case, :prod_add_case_2, :prod_cvd_case, :prod_cvd_case_2, :class_binding_ruling_number, :class_classification_notes]
  end

  def extract_embedded_csv text
    return [] if text.blank?

    # There's only going to be one line in here
    CSV.parse_line(text).map &:strip
  end

  def set_manufacturer_data product, line
    changed = false
    mid = line[6..12].map {|v| v.to_s.strip }

    # We only ever want to create a single factory for Amazon parts.
    manufacturer = product.factories.first

    if mid.all? {|v| v.blank? }
      if manufacturer
        manufacturer.destroy
        changed = true
      end
    else
      manufacturer = product.factories.create!(address_type: "MID") if manufacturer.nil?
      manufacturer.system_code = mid[0]
      manufacturer.name = mid[1]
      manufacturer.line_1 = mid[2]
      manufacturer.line_2 = mid[3]
      manufacturer.city = mid[4]
      manufacturer.country = country(mid[5])
      manufacturer.postal_code = mid[6]

      if manufacturer.changed?
        manufacturer.save!
        changed = true
      end
      
    end

    changed
  end

end; end; end; end