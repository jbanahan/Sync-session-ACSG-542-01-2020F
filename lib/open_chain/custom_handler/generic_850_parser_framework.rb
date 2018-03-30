require 'rex12'
require 'open_chain/integration_client_parser'
require 'open_chain/edi_parser_support'

# This class is meant to be extended for all 850 parsers that fit a fairly standard 
# parsing structure used to create an Order
# 
# The parser handles most of the nitty gritty of dealing w/ grouping EDI segments together
# based on header detail level and which lines they belong to.
#
# It also makes creating products associated with PO lines rather easy.
#
# These are the following methods you MUST implement when extending this class:
#
# =============================================================================================
# MANDATORY METHODS TO IMPLEMENT WHEN EXTENDING THIS CLASS:
# 
# prep_importer - Create / Find the importer company that will be associated with the order
# This method MUST return an importer Company record
#
# line_level_segment_list - This is a full list of every segment that can appear at the Line level (PO1) loop.  You MUST list every segment, and the first segment
# in the returned array MUST be the first segment that appears in the Line level EDI loop (which is almost always a "PO1" segment)
# 
# - standard_style(po1_segment, all_line_segments) - This method must return the style (Product.unique_identifier - minus the importer system code) value to use 
# for a specific OrderLine.  It is used both for creating products and for determing which product is linked to a specific PO1 line.
# This method must return the String value to use as the style/part number for the line
# 
# - update_standard_product(product, all_edi_segments, po1_segment, all_line_segments) - This method is used to populate / update any
# data required for a Product tied to a specific OrderLine.  The product WILL exist in the database already, if you are building variants you will need
# to build them inside this methods.
# This method MUST return true if the product data has been updated, false otherwise.
#
# - process_order_header(user, order, all_edi_segments) - Sets all data from the EDI into the order (you don't have to set OrderLine data here).
# Any return value is ignored.  For simplified handling of DTM and N1 loops you may implement the optional methods (see below) process_order_header_date, process_order_header_party.
#
# - process_standard_line(order, po1_segment, all_line_segments, product) - Creates / Updates data for the specific PO1 line loop provided.  The
# Product that is linked to the PO1 data is passed into the method, you do not need to find or update it at this point.
# No return value is expected.
# 
# =============================================================================================
# The following method is required if you are building variants:
# - standard_variant_identifier(po1_segment, all_line_segments) - Returns the string value to use as the variant identifier (generally will be the SKU)
#
# ============================================================================================= 
# The following methods are required ONLY if the 850 document has SLN (prepack) segments in it and the :explode_prepack configuration options is set to true:
#
# - prepack_style(po1_segment, all_line_segments, sln_segment, all_sln_segments) - This method must return the style (Product.unique_identifier - minus the importer system code) value to use 
# for a specific OrderLine that represents a prepack line (.ie a SLN segment).  It is used both for creating products and for determing which product is linked to a specific PO1 line.
# This method is required if the 850 has SLN segments in it.
#
# - update_prepack_product(product, all_edi_segments, po1_segment, all_line_segments, sln_segment, all_sln_segments) - This method is used to populate / update any
# data required for a Product tied to a specific prepack OrderLine.  The product WILL exist in the database already.
# This method MUST return true if the producdt data has been updated, false otherwise.
#
# - process_prepack_line(order, po1, sln, all_subline_segments, product) - Creates / Updates data for the specific PO1 line loop provided.  The
# Product that is linked to the PO1 data is passed into the method, you do not need to find or update it at this point.
# No return value is expected.
#
# ============================================================================================= 
# The following methods are required ONLY if the 850 document has SLN (prepack) segments in it and you are building variants:
# 
# - prepack_variant_identifier(po1_segment, line_segments, sln_segment, sln_segments) - Returns the string value to use as the variant identifier (generally will be the prepack item sku)
# 
# =============================================================================================
# OPTIONAL METHDOS TO IMPLEMENT
#
# - process_order_header_date(order, dtm_qualifier, date) - Set the date value (which is an ActiveSupport::TimeWithZone object) into the correct
# order header field.
# No return value is expected.
# 
# - process_order_header_party(order, n1_party_data) - Set the provided N1 party data into the order.  The data is already preparsed from the N1-N4 loop into a hash
# that is described below. No return value is expected.  A helper method named find_or_create_company_from_n1_data exists to turn this data hash into a Company object,
# another helper method named find_or_create_address_from_n1_data turns it into an Address object.
#
# {entity_type: <N101>, name: <N102>, id_code_qualifier: <N103>, id_code: <N104>, address: <Address object composed of data from N2-N4 address data>, country: <N404>}
#
# - cdef_uids - Returns an array of uids for custom definitions to use.  The is only needed if you intend on using the cdef helper method, which loads
# and caches custom definitions, relying on this cdef_uids method for the list of custom definitions needed for the parser.
#
# ==============================================================================================
# METHODS WHICH WHEN IMPLEMENTED CAN ENABLE OR DISABLE FUNCTIONALITY
# 


module OpenChain; module CustomHandler; class Generic850ParserFramework
  extend OpenChain::IntegrationClientParser
  include OpenChain::EdiParserSupport

  def initialize configuration = {}
    # In general, you'll want to set this to false on customer specific systems (ll, polo, etc)
    @prefix_identifiers_with_system_codes = configuration[:prefix_identifiers_with_system_codes].nil? ? true : configuration[:prefix_identifiers_with_system_codes]

    # If set to true, the system will not reject updates to orders that are shipping
    @allow_updates_to_shipping_orders = configuration[:allow_updates_to_shipping_orders].nil? ? false : configuration[:allow_updates_to_shipping_orders]
    # In the general case, we're not exploding prepacks onto the PO, we're going to be just handling the lines
    # as they are sent.  If this is set to true, then prepack methods listed above must be implemented and 
    # each SLN is expected to be its own OrderLine
    @explode_prepacks = configuration[:explode_prepacks].nil? ? false : configuration[:explode_prepacks]

    # Valid values handled by the framework are [:isa_date, :revision] 
    #- revision requires custom definition usage and the BEG04 segment to be used properly 
    # (incrementing version numbers are sent by the EDI sender)
    @track_order_by = configuration[:track_order_by].presence || :isa_date

    # If any value other than a 1 signifies a cancelled order, then you will need to set this coniguration value to the value
    # that signifies cancellation
    @canceled_order_transmission_code = configuration[:canceled_order_transmission_code].present? ? configuration[:canceled_order_transmission_code].to_i : 1
  end

  def process_transaction user, transaction, last_file_bucket:, last_file_path:
    edi_segments = transaction.segments
    beg_segment = find_segment(edi_segments, "BEG")

    purpose = order_purpose(beg_segment)
    
    if purpose != :cancel
      # It's a waste of time to lookup and create products on cancelled orders, so don't
      order_line_segment_loops = extract_loop(edi_segments, line_level_segment_list())
      product_cache = create_product_cache(user, last_file_path, edi_segments, order_line_segment_loops)
    end

    find_or_create_order(beg_segment, transaction, last_file_bucket, last_file_path) do |order|
      if purpose == :cancel
        process_cancelled_order(user, order, edi_segments)
      else
        process_order(user, order, edi_segments, product_cache)
      end

      # Give the implementing class a chance for a callback prior to saving to set any last values
      # Like if there is data from the lines that needs to be pulled up to the header, etc
      before_order_save(user, transaction, order) if self.respond_to?(:before_order_save)

      order.save!
      order.create_snapshot user, nil, last_file_path
    end
  end

  def process_cancelled_order user, order, edi_segments
    if !order.closed?
      order.close_logic user
    end
  end

  def process_order user, order, edi_segments, product_cache
    if !allow_updates_to_shipping_orders?
      raise EdiBusinessLogicError, "PO # '#{order.customer_order_number}' is already shipping and cannot be updated." if order.shipping?
    end

    handle_order_header(user, order, edi_segments)

    iterate_order_lines(extract_loop(edi_segments, line_level_segment_list())) do |po1, all_line_segments, sln, all_subline_segments|
      if sln
        handle_prepack_line(order, po1, all_line_segments, sln, all_subline_segments, product_cache)
      else
        handle_standard_line(order, po1, all_line_segments, product_cache)
      end
    end
  end


  def handle_order_header user, order, edi_segments
    #If the order is currently closed, re-open it
    if order.closed?
      order.reopen_logic user
    end

    process_order_header(user, order, edi_segments)

    # Collect all header level segements (.ie anything that comes before the first line level segment)...there can be N1's and DTM's at the line level or subline
    stop_segment = Array.wrap(line_level_segment_list()).first

    header_segments = []
    edi_segments.each do |seg|
      if seg.segment_type == stop_segment
        break
      else
        header_segments << seg
      end
    end

    extract_n1_loops(header_segments).each do |n1|
      process_order_header_n1(order, n1)
    end
    
    find_segments(header_segments, "DTM").each do |dtm_segment|
      process_order_header_dtm(order, dtm_segment)
    end

    nil
  end

  def process_order_header_dtm(order, dtm_segment)
    process_order_header_date(order, value(dtm_segment, 1), value(dtm_segment, 2)) if self.respond_to?(:process_order_header_date)
  end

  def process_order_header_n1(order, n1_loop)
    process_order_header_party(order, extract_n1_entity_data(n1_loop)) if self.respond_to?(:process_order_header_party)
  end

  def handle_standard_line order, po1, all_line_segments, product_cache
    style = standard_style(po1, all_line_segments)
    product = product_cache[style]

    process_standard_line(order, po1, all_line_segments, product)
  end

  def handle_prepack_line order, po1, all_line_segments, sln, all_subline_segments, product_cache
    style = prepack_style(po1, all_line_segments, sln, all_subline_segments)
    product = product_cache[style]

    process_prepack_line(order, po1, sln, all_subline_segments, product)
  end

  def find_or_create_company_from_n1_data data, company_type_hash: , other_attributes: {}
    prefix = prefix_identifiers_with_system_codes? ? importer.system_code : nil
    super(data, company_type_hash: company_type_hash, link_to_company: importer, system_code_prefix: prefix, other_attributes: other_attributes)
  end

  def parse_ship_mode code
    # This is the full "standard" list of ship mode codes (as listed in ECS / Delta)
    case code.to_s.upcase
    when "6"; "Military Official Mail"
    when "7"; "Mail"
    when "A"; "Air"
    when "AC"; "Air Charter"
    when "AE"; "Air Express"
    when "AF"; "Air Freight"
    when "AH"; "Air Taxi"
    when "AP"; "Air (Package Carrier)"
    when "AR"; "Armed Forces Courier Service (ARFCOS)"
    when "B"; "Barge"
    when "BB"; "Breakbulk Ocean"
    when "BP"; "Book Postal"
    when "BU"; "Bus"
    when "C"; "Consolidation"
    when "CC"; "Commingled Ocean"
    when "CE"; "Customer Pickup / Customer's Expense"
    when "D"; "Parcel Post"
    when "DA"; "Driveaway Service"
    when "DW"; "Driveaway, Truckaway, Towaway"
    when "E"; "Expedited Truck"
    when "ED"; "Air Mobility Command (AMC) Channel and Special Assignment Airlift Mission"
    when "F"; "Flyaway"
    when "FA"; "Air Freight Forwarder"
    when "FL"; "Motor (Flatbed)"
    when "G"; "Consignee Option"
    when "GG"; "Geographic Receiving/Shipping"
    when "GR"; "Geographic Receiving"
    when "GS"; "Geographic Shipping"
    when "H"; "Customer Pickup"
    when "HH"; "Household Goods Truck"
    when "I"; "Common Irregular Carrier"
    when "IP"; "Intermodal (Personal Property)"
    when "J"; "Motor"
    when "K"; "Backhaul"
    when "L"; "Contract Carrier"
    when "LA"; "Military Air"
    when "LD"; "Local Delivery"
    when "LT"; "Less Than Trailer Load (LTL)"
    when "M"; "Motor (Common Carrier)"
    when "MB"; "Motor (Bulk Carrier)"
    when "MP"; "Motor (Package Carrier)"
    when "MS"; "Military Sealift Command (MSC)"
    when "N"; "Private Vessel"
    when "O"; "Containerized Ocean"
    when "P"; "Private Carrier"
    when "PA"; "Pooled Air"
    when "PG"; "Pooled Piggyback"
    when "PL"; "Pipeline"
    when "PP"; "Pool to Pool"
    when "PR"; "Pooled Rail"
    when "PT"; "Pooled Truck"
    when "Q"; "Conventional Ocean"
    when "R"; "Rail"
    when "RC"; "Rail, Less than Carload"
    when "RO"; "Ocean (Roll on - Roll off)"
    when "RR"; "Roadrailer"
    when "S"; "Ocean"
    when "SB"; "Shipper Agent"
    when "SC"; "Shipper Agent (Truck)"
    when "SD"; "Shipper Association"
    when "SE"; "Sea/Air"
    when "SF"; "Surface Freight Forwarder"
    when "SR"; "Supplier Truck"
    when "SS"; "Steamship"
    when "ST"; "Stack Train"
    when "T"; "Best Way (Shippers Option)"
    when "TA"; "Towaway Service"
    when "TC"; "Cab (Taxi)"
    when "TT"; "Tank Truck"
    when "U"; "Private Parcel Service"
    when "VA"; "Motor (Van)"
    when "VE"; "Vessel, Ocean"
    when "VL"; "Vessel, Lake"
    when "W"; "Inland Waterway"
    when "WP"; "Water or Pipeline Intermodal Movement"
    when "X"; "Intermodal (Piggyback)"
    when "Y"; "Military Intratheater Airlift Service"
    when "Y1"; "Ocean Conference Carrier"
    when "Y2"; "Ocean Non-Conference Carrier"
    when "ZZ"; "Mutually defined"
    else
      nil
    end
  end

  def find_or_create_order beg_segment, transaction, last_file_bucket, last_file_path
    if prefix_identifiers_with_system_codes?
      cust_order_number = customer_order_number(beg_segment)
      order_number = prefix_value(importer, cust_order_number)
    else
      cust_order_number = nil
      order_number = customer_order_number(beg_segment)
    end

    order = nil
    edi_segments = transaction.segments
    Lock.acquire("Order-#{order_number}") do 
      o = Order.where(order_number: order_number, importer_id: importer.id).first_or_create! customer_order_number: cust_order_number
      order = o if process_file?(o, beg_segment, edi_segments, transaction)
    end

    if order
      Lock.with_lock_retry(order) do
        # Double call of process_file? happens here because the with lock retry reloads the order object, and it's very possible another process
        # has come along and updated the order since then and updated the revision number since we've been waiting here on the update lock
        if process_file?(order, beg_segment, edi_segments, transaction)
          order.processing_errors = nil
          order.last_file_bucket = last_file_bucket
          order.last_file_path = last_file_path

          if track_order_by == :revision
            set_revision_info(order, beg_segment)
          elsif track_order_by == :isa_date
            order.last_exported_from_source = parse_isa_date(transaction)
          end

          yield order
        end
      end
    end
  end

  def customer_order_number beg_segment
    value(beg_segment, 3)
  end

  def revision beg_segment
    value(beg_segment, 4)
  end

  def process_file? order, beg_segment, edi_segments, transaction
    track_by = track_order_by
    if track_by == :revision
      return process_file_based_on_revision?(order, beg_segment)
    elsif track_by == :isa_date
      return process_file_based_on_isa_date?(order, transaction)
    end
  end

  def process_file_based_on_isa_date?(order, transaction)
    isa_date = parse_isa_date(transaction)

    order.last_exported_from_source.nil? || order.last_exported_from_source <= isa_date
  end

  def parse_isa_date transaction
    # Format of date should be YYmmdd, time should be HHMM
    date = value(transaction.isa_segment, 9)
    time = value(transaction.isa_segment, 10)

    if date.length == 6
      datetime = "20#{date}" + time
    else
      datetime = date + time
    end

    d = ActiveSupport::TimeZone["America/New_York"].parse datetime
    raise EdiStructuralError, "ISA Timestamp is not a valid date.  ISA09 = #{date} / ISA10 = #{time}." unless d
    d
  end

  def process_file_based_on_revision? order, beg_segment
    rev = revision(beg_segment)
    rev.to_i >= order.custom_value(cdefs[:ord_revision]).to_i
  end

  def set_revision_info order, beg_segment
    order.find_and_set_custom_value(cdefs[:ord_revision], revision(beg_segment)) if cdef_present?(:ord_revision)
    # Since virtually everyone that's going to see the revision date is going to see it the US / Eastern Time, set the date relative to that.
    order.find_and_set_custom_value(cdefs[:ord_revision_date], ActiveSupport::TimeZone["America/New_York"].now.to_date) if cdef_present?(:ord_revision_date)
  end

  def order_purpose beg_segment
    purpose = value(beg_segment, 1).to_i

    if purpose == canceled_order_transmission_code
      return :cancel
    elsif purpose == 0
      :create
    else
      :update
    end
  end

  def create_product_cache user, filename, all_segments, line_level_segments
    cache = {variants: {}}
    products_to_snapshot = {}
    iterate_order_lines(line_level_segments) do |po1, all_line_segments, sln, all_subline_segments|
      if sln
        product = find_or_create_prepack_product(all_segments, po1, all_line_segments, sln, all_subline_segments, cache)
      else
        product = find_or_create_standard_product(all_segments, po1, all_line_segments, cache)
      end

      products_to_snapshot[product.unique_identifier] = product if product
    end

    products_to_snapshot.values.each {|product| product.create_snapshot user, nil, filename }

    # We don't need the variants in the cache any longer, it's only there to prevent sending the product / variant combination through
    # to the update_*_product methods if nothing changed.  When building the order lines, the implementing class should reference
    # the variants directly from the product object itself
    cache.delete :variants
    cache
  end

  def iterate_order_lines(line_level_segments)
    line_level_segments.each do |line_segments|
      find_segments(line_segments, "PO1") do |po1|
        if explode_prepacks? && prepack_line?(po1)
          extract_loop(line_segments, prepack_segment_list).each do |subline_segments|
            sln = find_segment(subline_segments, "SLN")
            yield po1, line_segments, sln, subline_segments
          end 
        else
          yield po1, line_segments, nil, nil
        end
      end
    end

    nil
  end

  def find_or_create_standard_product all_segments, po1_segment, line_segments, cache
    style = standard_style(po1_segment, line_segments)
    variant_identifier = standard_variant_identifier(po1_segment, line_segments) if self.respond_to?(:standard_variant_identifier)

    product = cache[style]
    variant = cache[:variants][variant_cache_key(style, variant_identifier)]

    # If we've already seen both the product and the variant (or just the product if we're not dealing w/ variants)
    # then we can skip the update calls below...and return nil, indicating nothing was updated and we shouldn't later snapshot the product
    return nil if (variant_identifier.nil? && !product.nil?) || (!variant.nil? && !product.nil?)

    product = find_or_create_product(style)


    Lock.with_lock_retry(product) do
      # Some 850 feeds send data about products at the Order level (like in header level PID segments), so we need to pass all that data
      # down to the extending class
      if update_standard_product(product, all_segments, po1_segment, line_segments)
        product.save!
      end
    end

    cache[style] = product
    if !variant_identifier.blank?
      variant = product.variants.find {|v| v.variant_identifier == variant_identifier }
      cache[:variants][variant_cache_key(style, variant_identifier)] = variant if variant
    end

    product
  end

  def find_or_create_prepack_product all_segments, po1_segment, line_segments, sln_segment, sln_segments, cache
    style = prepack_style(po1_segment, line_segments, sln_segment, sln_segments)
    variant_identifier = prepack_variant_identifier(po1_segment, line_segments, sln_segment, sln_segments) if self.respond_to?(:prepack_variant_identifier)

    product = cache[style]
    variant = cache[:variants][variant_cache_key(style, variant_identifier)]

    # If we've already seen both the product and the variant (or just the product if we're not dealing w/ variants)
    # then we can skip the update calls below...and return nil, indicating nothing was updated and we shouldn't later snapshot the product
    return nil if (variant_identifier.nil? && !product.nil?) || (!variant.nil? && !product.nil?)
    
    product = find_or_create_product(style)

    Lock.with_lock_retry(product) do
      # Some 850 feeds send data about products at the Order level (like in header level PID segments), so we need to pass all that data
      # down to the extending class
      if update_prepack_product(product, all_segments, po1_segment, line_segments, sln_segment, sln_segments)
        product.save!
      end
    end

    cache[style] = product
    if !variant_identifier.blank?
      variant = product.variants.find {|v| v.variant_identifier == variant_identifier }
      cache[:variants][variant_cache_key(style, variant_identifier)] = variant if variant
    end
    
    product
  end

  def find_or_create_product style
    # All we're really doing here is setting up the basic information like style and then
    # we'll rely on the callback we issue after locking the product row to update all other information
    product = nil
    unique_identifier = prefix_value(importer, style)
    Lock.acquire("Product-#{unique_identifier}") do 
      product = Product.where(unique_identifier: unique_identifier, importer_id: importer.id).first_or_initialize

      unless product.persisted?
        # If we're prefixing identifiers, it means that we're tracking the part number separately w/ a custom value too, so make sure to set it.
        product.find_and_set_custom_value(cdefs[:prod_part_number], style) if prefix_identifiers_with_system_codes? && cdef_present?(:prod_part_number)
        product.save!
      end
    end

    product
  end

  def prepack_line? po1_segment
    value(po1_segment, 3).to_s.upcase == "AS"
  end

  def explode_prepacks?
    @explode_prepacks
  end

  def prefix_identifiers_with_system_codes?
    @prefix_identifiers_with_system_codes
  end

  def allow_updates_to_shipping_orders?
    @allow_updates_to_shipping_orders
  end

  def track_order_by
    @track_order_by
  end

  def canceled_order_transmission_code
    @canceled_order_transmission_code
  end

  def prefix_value company, value
    prefix_identifiers_with_system_codes? ? "#{company.system_code}-#{value}" : value
  end

  def importer
    @imp ||= prep_importer
    @imp
  end

  def cdefs
    # It's possible that the implementing class won't use any custom definitions.
    @cdefs ||= begin
      if self.respond_to?(:cdef_uids)
        self.class.prep_custom_definitions(self.cdef_uids)
      else
        {}
      end
    end

    @cdefs
  end

  def cdef_present? uid
    cdefs[uid.to_sym].present?
  end

  def variant_cache_key product_style, variant_identifier
    "#{product_style}~#{variant_identifier}"
  end

end; end; end
