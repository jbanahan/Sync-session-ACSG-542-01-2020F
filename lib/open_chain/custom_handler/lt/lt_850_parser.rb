require 'open_chain/custom_handler/generic_850_parser_framework'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/integration_client_parser'
require 'open_chain/mutable_boolean'

module OpenChain; module CustomHandler; module Lt; class Lt850Parser < OpenChain::CustomHandler::Generic850ParserFramework
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include OpenChain::IntegrationClientParser

  def self.integration_folder
    ["www-vfitrack-net/_lt_850", "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_lt_850"]
  end

  def self.pre_process_data data
    # LT 850's appear to be Windows encoded.  We received a file where there were windows em-dashes
    # in the vendors name.
    data.force_encoding("Windows-1252")
    nil
  end

  ########## required methods

  def prep_importer
    lt = Company.where(importer: true, system_code: "LOLLYT").first
    raise "No Importer account exists with a system code of 'LOLLYT'." if lt.nil?
    lt
  end

  def process_order user, order, edi_segments, product_cache
    begin
      super
    # we don't want these generating emails
    rescue EdiBusinessLogicError => e
      order.add_processing_error e.message
      order.save!
    end
  end

  def line_level_segment_list
    ["PO1", "PO4", "CTP", "PID", "REF", "N1", "N3", "N4"]
  end

  def standard_style po1_segment, all_line_segments
    find_segment_qualified_value(po1_segment, "ST")
  end

  def update_standard_product product, edi_segments, po1_segment, line_segments
    product.name = find_value_by_qualifier line_segments, "PID02", "08", value_index: 5
    product.changed?
  end

  def process_order_header user, order, edi_segments
    order.order_lines.destroy_all

    beg = find_segment(edi_segments, "BEG")
    refs = find_segments(edi_segments, "REF")
    ns = find_segments(edi_segments, "N1")
    
    order.order_date = parse_dtm_date_value(value(beg, 5)).try(:to_date)
    order.mode = find_value_by_qualifier refs, "REF01", "LSD"
    order.terms_of_sale = find_element_value edi_segments, "ITD01"
    order.fob_point = find_element_value edi_segments, "FOB03"
    order.currency = find_element_value edi_segments, "CUR02"
    order.season = find_value_by_qualifier refs, "REF01", "AAY"
    division = Division.new(name: find_value_by_qualifier(ns, "N101", "DV"), company: order.importer)
    order.division = division
    order.find_and_set_custom_value(cdefs[:ord_type], value(beg, 2))
    order.find_and_set_custom_value(cdefs[:ord_country_of_origin], find_value_by_qualifier(refs, "REF01", "JY"))
    order.find_and_set_custom_value(cdefs[:ord_assigned_agent], find_value_by_qualifier(ns, "N101", "AG"))
  end

  def process_standard_line order, po1_segment, line_segments, product
    line = order.order_lines.build
    line.product = product
    line.quantity = value(po1_segment, 2)
    line.unit_of_measure = value(po1_segment, 3)
    line.sku = find_value_by_qualifier [po1_segment], "PO116", "UP"
    line.unit_msrp = find_value_by_qualifier line_segments, "CTP02", "RTL"
    refs = find_segments(line_segments, "REF")

    line.find_and_set_custom_value(cdefs[:ord_line_color], find_value_by_qualifier([po1_segment], "PO108", "CL"))
    line.find_and_set_custom_value(cdefs[:ord_line_color_description], find_value_by_qualifier(line_segments, "PID02", "73", value_index: 5))
    line.find_and_set_custom_value(cdefs[:ord_line_season], find_value_by_qualifier(refs, "REF01", "SE"))
    line.find_and_set_custom_value(cdefs[:ord_line_size], find_value_by_qualifier([po1_segment], "PO112", "IZ"))
    line.find_and_set_custom_value(cdefs[:ord_line_size_description], find_value_by_qualifier(line_segments, "PID02", "74", value_index: 5))

    # N1 factory and ship_to segments are line level, so re-purposing this method
    extract_n1_loops(line_segments).each { |n1| process_order_header_n1(order, n1) }
      
    hts = find_value_by_qualifier refs, "REF01", "HTS"
    if hts != "9999.99.9999"
      line.line_number = value(po1_segment, 1)
      line.hts = hts&.gsub('.', '')
      line.price_per_unit = value(po1_segment, 4)
    else
      # HTS and price_per_unit is split among REF*HST segments. Resulting lines share all of the already-assigned data.
      explode_line line, refs, po1_segment
    end
  end

  ########## optional methods

  def process_order_header_date order, qualifier, date
    case qualifier
    when "010"
      order.ship_window_start = date
    when "001"
      order.ship_window_end = date
    end
  end

  def process_order_header_party order, party_data
    # nil checks to prevent extra processing when invoked at line level
    if party_data[:entity_type] == "MP" && order.factory.nil?
      order.factory = find_or_create_company_from_n1_data(party_data, system_code_prefix: "Factory", company_type_hash: {factory: true}, other_attributes: {mid: party_data[:id_code]})
    elsif party_data[:entity_type] == "ST" && order.ship_to.nil?
      order.ship_to = find_or_create_address_from_n1_data(party_data, importer)
    elsif party_data[:entity_type] == "VN"
      #VN = Vendor 
      order.vendor = find_or_create_company_from_n1_data(party_data, system_code_prefix: "Vendor", company_type_hash: {vendor: true})
    end
  end

  def cdef_uids
    [:ord_type, :ord_country_of_origin, :ord_assigned_agent, :ord_line_color, :ord_line_color_description, 
     :ord_line_season, :ord_line_size, :ord_line_size_description, :prod_part_number]
  end

  ##########

  def explode_line line, ref_segments, po1_segment
    hsts = ref_segments.select{ |r| r.element(1)&.value == "HST" && r.element(2)&.value != "9999.99.9999" }
    raise EdiStructuralError, "Order # #{line.order.customer_order_number}, UPC # #{line.sku}: Expecting REF with HST qualifier but none found" if hsts.count.zero?
    split_lines = copy_lines line, (hsts.count - 1)
    hsts.each_with_index do |ref, i|
      ln = split_lines.shift
      ln.hts = value(ref, 2)&.gsub('.', '')
      ln.price_per_unit = BigDecimal ref.element(-1).sub_element(-1)&.value
      ln.line_number = value(po1_segment, 1).to_i * 100 + (i + 1)
    end
    
    nil
  end

  def copy_lines line, n
    o = line.order
    split_lines = Array.new(n) do
      ln = o.order_lines.build(line.attributes)
      line.custom_values.each { |cv| ln.custom_values.build cv.attributes }
      ln
    end
    
    split_lines.unshift line
  end


end; end; end; end
