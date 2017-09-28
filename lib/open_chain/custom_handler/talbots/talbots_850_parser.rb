require 'open_chain/custom_handler/generic_850_parser_framework'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/mutable_boolean'

module OpenChain; module CustomHandler; module Talbots; class Talbots850Parser < OpenChain::CustomHandler::Generic850ParserFramework
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def self.integration_folder
    "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_talbots_850"
  end

  def prep_importer
    Company.where(importer: true, system_code: "TALBO").first
  end

  def cdef_uids
    [:prod_part_number, :prod_fish_wildlife, :prod_fabric_content, :ord_type, :ord_country_of_origin, :ord_buyer_order_number, :ord_buyer, :ord_line_buyer_item_number, :ord_line_color, :ord_line_size, :ord_line_size_description, :var_hts_code, :var_color, :var_size]
  end

  def standard_style po1, all_segments
    # The style as Talbots sends them to us includes the season code (for some reason)
    # Strip that off as that doesn't appear on the 856 or the commerical invoices.
    style = find_segment_qualified_value(po1, "VA")
    # This matches everythign prior to the last /
    if style =~ /(.*)\/.*/
      style = $1
    end

    style
  end

  def process_order_header user, order, edi_segments
    # Since Talbots doesn't use line_numbers in any real meaningful way, we're going to destroy every line and rebuild them on each send
    # (This has the side effect of not being able to update orders once any line has started shipping)
    order.order_lines.destroy_all

    beg = find_segment(edi_segments, "BEG")

    order.find_and_set_custom_value(cdefs[:ord_type], value(beg, 2))
    order.order_date = parse_dtm_date_value(value(beg, 5)).try(:to_date)

    fob = find_segment(edi_segments, "FOB")
    order.terms_of_payment = value(fob, 1)
    order.terms_of_sale = value(fob, 3)
    order.fob_point = value(fob, 3)
    if value(fob, 6).to_s.upcase == "OR"
      order.find_and_set_custom_value(cdefs[:ord_country_of_origin], value(fob, 7))
    end

    td5 = find_segment(edi_segments, "TD5")

    order.mode = parse_ship_mode(value(td5, 4))
    order.find_and_set_custom_value(cdefs[:ord_buyer_order_number], find_ref_value(edi_segments, "PO"))

    per = find_segments_by_qualifier(edi_segments, "PER01", "BD").first
    order.find_and_set_custom_value(cdefs[:ord_buyer], value(per, 2)) if per
    order.season = find_message_value(edi_segments, "THEME")

    @vendor_system_code = find_ref_value(edi_segments, "VN")
  end

  def before_order_save user, transaction, order
    # Make sure the factory is linked to the vendor
    if order.vendor && order.factory
      order.vendor.linked_companies << order.factory unless order.vendor.linked_companies.include?(order.factory)
    end
  end

  def parse_ship_mode value
    case value.to_s.upcase
    when "A"; "Air"
    when "M"; "Motor (Common Carrier)"
    when "R"; "Rail"
    when "S"; "Ocean"
    when "B"; "Boat"
    when "H"; "Hybrid"
    when "D"; "Domestic Truck"
    when "O"; "Mini-land bridge"
    else; nil
    end
  end

  def process_order_header_date order, qualifier, date
    case qualifier
    when "037"
      order.ship_window_start = date
    when "002"
      order.ship_window_end = date
    when "001"
      order.first_expected_delivery_date = date
    end
  end

  def process_order_header_party order, party_data
    if party_data[:entity_type] == "SU"
      #SU = Factory
      order.factory = find_or_create_company_from_n1_data(party_data, company_type_hash: {factory: true}, other_attributes: {mid: party_data[:id_code]})
    elsif party_data[:entity_type] == "ST"
      #ST = Ship To
      order.ship_to = find_or_create_address_from_n1_data(party_data, importer)
    elsif party_data[:entity_type] == "VN"
      #VN = Vendor - We have use a REF value to identify the vendor system code (for some reason they can't send it on the N1)
      raise "Cannot set vendor data without a 'VN' REf segment present." if @vendor_system_code.blank?

      party_data[:id_code] = @vendor_system_code

      order.vendor = find_or_create_company_from_n1_data(party_data, company_type_hash: {vendor: true})
    end
  end

  def line_level_segment_list
    ["PO1", "PO4"]
  end

  def process_standard_line order, po1, all_line_segments, product
    # So what's happening here is this:
    # 1) For Eaches and Prepacks, Talbots uses the same line number across multiple PO1 segments (WTF #1)
    # 2) Talbots doesn't use SLN (sublines) to represent prepacks.  (WTF #2) When they have a prepack, they 
    #    send a PO1 for each item in the pack and then a PO4 indicating the pack number (sorta like a line number)
    #    and the total # of packs.
    # 3) Talbots sends the same SKU on multiple different PO1 lines frequently.
    # 4) The 856 references items from the PO by SKU.  Along w/ #3, this means that if we did put every PO1 on its own line
    #    when the 856 comes in we won't know which line they're shipping (shipper doesn't care), so we can just link the 
    #    856 against some random line (which will probably end up showing an overshipment), or we can roll up the PO1 line
    #    data based on SKU and then the 856 has a single line to choose from and the shipment counts etc are all accurate.
    variant_identifier = standard_variant_identifier(po1, all_line_segments)
    line = order.order_lines.find {|l| l.sku == variant_identifier }

    if line.nil?
      line = order.order_lines.build line_number: (order.order_lines.length + 1)

      line.product = product
      line.unit_of_measure = value(po1, 3)
      line.price_per_unit = BigDecimal(value(po1, 4))
      line.sku = find_segment_qualified_value(po1, "SK")
      line.hts = find_segment_qualified_value(po1, "H1").to_s.gsub(".", "")

      line.find_and_set_custom_value(cdefs[:ord_line_buyer_item_number], find_segment_qualified_value(po1, "IT"))
      line.find_and_set_custom_value(cdefs[:ord_line_color], find_segment_qualified_value(po1, "VE"))
      line.find_and_set_custom_value(cdefs[:ord_line_size], find_segment_qualified_value(po1, "ZZ"))
      line.find_and_set_custom_value(cdefs[:ord_line_size_description], find_segment_qualified_value(po1, "SD"))
      
      variant = product.variants.find {|v| v.variant_identifier == variant_identifier}
      line.variant = variant if variant
      line.quantity = BigDecimal("0")
    end

    # OS = Talbots bastardized version of a prepack
    prepack_multiplier = (order.custom_value(cdefs[:ord_type]) == "OS") ? BigDecimal(find_element_value(all_line_segments, "PO402").to_i) : 1
    line.quantity = line.quantity + (BigDecimal(value(po1, 2)) * prepack_multiplier)

    line
  end

  def update_standard_product product, edi_segments, po1_segment, line_segments
    changed = MutableBoolean.new false

    set_custom_value(product, fish_wildlife?(edi_segments), :prod_fish_wildlife, changed)
    set_custom_value(product, find_message_value(edi_segments, "F "), :prod_fabric_content, changed, skip_nil_values: true)
    product.name = find_message_value(edi_segments, "ITEM DESC")

    hts = find_segment_qualified_value(po1_segment, "H1").to_s.gsub(".", "")
    tariff = find_or_create_us_tariff_record(product)
    if tariff.hts_1 != hts
      tariff.hts_1 = hts
      changed.value = true
    end

    variant = update_variant(product, po1_segment, line_segments, hts, changed)

    changed.value || product.changed? || variant.changed?
  end

  def find_or_create_us_tariff_record product
    classification = product.classifications.find {|c| c.country_id == us.id }
    classification = product.classifications.build(country_id: us.id) if classification.nil?
    tariff = classification.tariff_records[0]
    tariff = classification.tariff_records.build if tariff.nil?

    tariff
  end

  def update_variant product, po1, line_segments, hts, changed
    variant_identifier = standard_variant_identifier(po1, line_segments)
    variant = product.variants.find {|v| v.variant_identifier == variant_identifier}
    variant = product.variants.build(variant_identifier: variant_identifier) if variant.nil?
    set_custom_value(variant, hts, :var_hts_code, changed)
    set_custom_value(variant, find_segment_qualified_value(po1, "VE"), :var_color, changed, skip_nil_values: true)
    set_custom_value(variant, find_segment_qualified_value(po1, "ZZ"), :var_size, changed, skip_nil_values: true)

    variant
  end

  def fish_wildlife? edi_segments
    find_segments_by_qualifier(edi_segments, "PID04", "TF").each {|seg| return true if value(seg, 8).to_s.upcase == "Y"}
    # Purposefully returning nil, I only want Fish/Wildlife field to show on screen if it's true (nil custom values don't get shown on screen)
    nil
  end

  def product_description edi_segments
    find_segments(edi_segments).each
  end

  def find_message_value edi_segments, message_identifier
    find_segments(edi_segments, "MSG").each do |msg|
      message = value(msg, 1)
      if message.starts_with?(message_identifier)
        return message[(message_identifier.length + 1)..-1].strip
      end
    end
    nil
  end

  def set_custom_value obj, value, uid, changed, skip_nil_values: false
    return if value.nil? && skip_nil_values

    cval = obj.custom_value(cdefs[uid])
    if cval != value
      obj.find_and_set_custom_value(cdefs[uid], value)
      changed.value = true
    end

    nil
  end

  def us
    @us ||= Country.where(iso_code: "US").first
    raise "Failed to find US country." unless @us
    @us
  end

  def standard_variant_identifier po1_segment, line_segments
    find_segment_qualified_value(po1_segment, "SK")
  end


end; end; end; end