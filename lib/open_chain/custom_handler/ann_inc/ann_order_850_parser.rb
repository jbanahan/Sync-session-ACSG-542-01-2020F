require 'rex12'
require 'open_chain/integration_client_parser'
require 'open_chain/edi_parser_support'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; module AnnInc; class AnnOrder850Parser
  extend OpenChain::IntegrationClientParser
  include OpenChain::EdiParserSupport
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def self.integration_folder
    "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_ann_850"
  end

  def self.parse data, opts={}
    REX12::Document.each_transaction(data) do |transaction|
      self.delay.process_transaction(transaction, last_file_bucket: opts[:bucket], last_file_path: opts[:key])
    end
  end

  def self.process_transaction transaction, last_file_bucket:, last_file_path:
    # Normally, we might wrap this in a block and do exception handling, however, there's really no business logic that should
    # ever actually require raising errors, so if anything is raised, it's really a bug that should be seen and taken care of
    # by a developer (or a transient issue which will get taken care of when delayed jobs retries the job)
    self.new.process_order User.integration, transaction, last_file_bucket: last_file_bucket, last_file_path: last_file_path
  end

  def process_order(user, transaction, last_file_bucket:, last_file_path:)
    edi_segments = transaction.segments

    beg_segment = find_segment(edi_segments, "BEG")
    cancelled = value(beg_segment, 1).to_i == 3

    # We need to FIRST generate all the products referenced by this PO, this is done outside the main 
    # order transaction because of transactional race-conditions that occur when trying to create products
    # inside the order transaction, resulting in the very real potential to create duplicate products.
    if !cancelled
      # It's a waste of time to lookup and create products on cancelled orders, so don't
      po1_segments = find_segments(edi_segments, "PO1")
      products = create_products(user, last_file_path, po1_segments, find_ref_value(edi_segments, "19"))
    end

    vendor = find_vendor(extract_n1_loops(edi_segments, qualifier: "VN", stop_segments: "PO1").first)
    factory = find_factory(vendor, extract_n1_loops(edi_segments, qualifier: "MP", stop_segments: "PO1").first)
    
    find_or_create_order(transaction, beg_segment, last_file_bucket, last_file_path) do |order|
      if cancelled
        process_cancelled_order(order, user, last_file_path)
      else
        order.vendor = vendor
        order.factory = factory
        process_order_header(order, all_segments_up_to(edi_segments, "PO1"))

        order_line_segments = extract_loop(edi_segments, ["PO1", "LIN", "PO3", "PO4", "REF", "DTM", "TC2", "TD1", "TD5", "SLN"])

        lines = []
        order_line_segments.each do |line_segments|
          line = process_order_line(order, products, line_segments)
          lines << line unless line.nil?
        end

        # Destroy any line that was not sent
        sent_lines = Set.new lines.map(&:line_number)

        order.order_lines.each do |line|
          # We don't do ann shipment tracking at the moment, but we might, so just add this here anyway
          line.destroy unless sent_lines.include?(line.line_number) || line.shipping?
        end

        order.save!
        order.create_snapshot user, nil, last_file_path
      end
    end
  end

  def find_or_create_order transaction, beg_segment, last_file_bucket, last_file_path
    cust_order_number = value(beg_segment, 3)
    file_sent = isa_sent_time(transaction.isa_segment)
    order_number = "#{ann_importer.system_code}-#{cust_order_number}"
    order = nil
    Lock.acquire("Order-#{order_number}") do 
      o = Order.where(order_number: order_number, importer_id: ann_importer.id).first_or_create! customer_order_number: cust_order_number, last_exported_from_source: file_sent
      order = o if process_file?(o, file_sent)
    end

    if order
      Lock.with_lock_retry(order) do
        if process_file?(order, file_sent)
          order.last_file_bucket = last_file_bucket
          order.last_file_path = last_file_path
          yield order
        end
      end
    end

    order
  end

  def isa_sent_time isa_segment
    # ISA dates are sent YYMMDD...just plop a 20 in front of that so that it parses correctly...we'll never get dates from 1900's.
    ActiveSupport::TimeZone["America/New_York"].parse("20" + value(isa_segment, 9) + value(isa_segment, 10))
  end

  def process_file? order, file_sent
    order.last_exported_from_source.nil? || file_sent >= order.last_exported_from_source
  end

  def process_order_header order, edi_segments
    beg_segment = find_segment(edi_segments, "BEG")

    order.order_date = parse_dtm_date_value(value(beg_segment, 5)).try(:to_date)
    order.find_and_set_custom_value(cdefs[:ord_type], program_type(edi_segments))
    order.find_and_set_custom_value(cdefs[:ord_division], find_ref_value(edi_segments, "19"))
    order.find_and_set_custom_value(cdefs[:ord_department], find_ref_value(edi_segments, "DP"))
    
    order
  end

  def process_cancelled_order order, user, filename
    if !order.closed?
      order.close_logic user
      order.save!
      order.create_snapshot user, nil, filename
    end
  end

  def program_type edi_segments
    # It looks like ANN sends two ZZ program type REF segments..one is the numeric value and the other is
    # the text value.  We're looking to only use the text one.
    refs = find_ref_values(edi_segments, "ZZ")
    division = nil
    if refs.length > 0
      # find the ref value where REF02 is not a number.
      division = refs.find {|r| r.to_i == 0}
    end

    division
  end

  def process_order_line order, products, line_segments
    # Use the SAP line number as our internal line number..
    sap_line_number = find_elements_by_qualifier(line_segments, "LIN", "ZZ", 2, 3).first
    # Just skip the line if sap line number is blank
    return if sap_line_number.blank?

    sap_line_number = sap_line_number.to_i

    order_line = order.order_lines.find {|ol| ol.line_number == sap_line_number }
    if order_line.nil?
      order_line = order.order_lines.build line_number: sap_line_number
    end

    po1_segment = find_segment(line_segments, "PO1")
    style = value(po1_segment, 15)

    order_line.product = products[style]
    # This should never really happen, if it does something's screwed up w/ the parser since we're creating 
    # parts on the fly for this.
    raise "Failed to find product '#{style}' for Order # '#{order.customer_order_number}'" if order_line.product.nil?

    # Quantity should always be the total number of units ordered
    order_line.sku = value(po1_segment, 7)
    
    order_line.unit_of_measure = value(po1_segment, 3)
    order_line.find_and_set_custom_value(cdefs[:ord_line_color], value(po1_segment, 9))
    order_line.find_and_set_custom_value(cdefs[:ord_line_color_description], value(po1_segment, 19))
    if (prf = BigDecimal(find_elements_by_qualifier(line_segments, "PO3", "PRF", 3, 4).first.to_s)).nonzero?
      order_line.find_and_set_custom_value(cdefs[:ord_line_design_fee], prf)
    end
    
    order_line.find_and_set_custom_value(cdefs[:ord_line_ex_factory_date], find_date_value(line_segments, "371"))
    order_line.find_and_set_custom_value(cdefs[:ord_line_planned_available_date], find_date_value(line_segments, "169"))
    order_line.find_and_set_custom_value(cdefs[:ord_line_planned_dc_date], find_date_value(line_segments, "017"))

    order_line.hts = find_elements_by_qualifier(line_segments, "TC2", "A", 1, 2).first

    if order_line.unit_of_measure == "PK"
      units_per_prepack = find_element_value(line_segments, "PO414").to_i
      prepacks_ordered = value(po1_segment, 2).to_i

      order_line.find_and_set_custom_value(cdefs[:ord_line_units_per_inner_pack], units_per_prepack)
      order_line.find_and_set_custom_value(cdefs[:ord_line_prepacks_ordered], prepacks_ordered)
      order_line.quantity = units_per_prepack * prepacks_ordered

      # Show the sizes of the first and last prepack and then just add a hyphen...like "00 - 16"
      sizes = find_elements_by_qualifier(line_segments, "SLN", "SZ", 19, 20)
      if sizes.length == 1
        size = sizes[0]
      elsif sizes.length > 1
        size = "#{sizes[0]} - #{sizes[-1]}"
      else
        size = nil
      end
      order_line.find_and_set_custom_value(cdefs[:ord_line_size], size)

      # The First Cost Price is the cost per prepack...we want the actual unit price for prepacks
      order_line.price_per_unit = (BigDecimal(find_elements_by_qualifier(line_segments, "PO3", "FCP", 3, 4).first.to_s) / units_per_prepack).round(2, :half_up)
    else
      order_line.find_and_set_custom_value(cdefs[:ord_line_size], value(po1_segment, 13))
      order_line.quantity = BigDecimal(value(po1_segment, 2).to_s)
      order_line.price_per_unit = BigDecimal(find_elements_by_qualifier(line_segments, "PO3", "FCP", 3, 4).first.to_s)
    end

    order_line
  end

  def create_products user, filename, po1_segments, brand
    products = {}

    # Ann prepacks are just different sizes of the same garment or just multiple of the same garment inside of 
    # inner packs...so we don't need to bother with them when making products
    po1_segments.each do |segment|
      style = value(segment, 15)
      style_description = value(segment, 17)

      # The same style is generally referenced on most lines of an order, so save some db lookups here.
      next unless products[style].nil?

      products[style] = find_or_create_product(style, style_description, brand, user, filename)
    end

    products
  end

  def find_or_create_product style, style_description, brand, user, filename
    unique_identifier = "#{ann_importer.system_code}-#{style}"
    p = nil
    Lock.acquire("Product-#{unique_identifier}") do
      product = Product.where(unique_identifier: unique_identifier, importer_id: ann_importer.id).first_or_initialize

      unless product.persisted?
        product.find_and_set_custom_value(cdefs[:prod_part_number], style)
      end

      # Don't blank out the style description if the PO doesn't have it..looks like it's always there, but 
      # don't eliminate it if it's not.
      product.name = style_description unless style_description.blank?

      existing_brand = product.custom_value(cdefs[:prod_brand])
      # I'm not really sure why, but custom value changes don't seem to register in product.changed?, so track this
      # directly
      changed = false
      if existing_brand != brand
        product.find_and_set_custom_value(cdefs[:prod_brand], brand)
        changed = true
      end

      if changed || product.changed? || !product.persisted?
        product.save!
        product.create_snapshot user, nil, filename
      end

      p = product
    end

    p
  end

  def cdefs
    @cd ||= self.class.prep_custom_definitions([:ord_type, :ord_division, :ord_department, :ord_line_color, :ord_line_color_description, :ord_line_design_fee, 
      :ord_line_ex_factory_date, :ord_line_planned_available_date, :ord_line_planned_dc_date, :ord_line_prepacks_ordered, :ord_line_units_per_inner_pack,
      :ord_line_size, :prod_part_number, :prod_brand])
  end

  def ann_importer
    @ann ||= Company.importers.where(system_code: "ATAYLOR").first
    raise "No Ann Taylor importer found with system code 'ATAYLOR'." unless @ann

    @ann
  end

  def find_vendor vendor_segments
    return nil if vendor_segments.blank?

    n1 = find_segment vendor_segments, "N1"

    id = value(n1, 4)
    system_code = "#{ann_importer.system_code}-VN-#{id}"
    vendor = Company.vendors.where(system_code: system_code).first

    return vendor unless vendor.nil?

    Lock.acquire(system_code) do
      vendor = Company.where(system_code: system_code).first_or_create! name: value(n1, 2), vendor: true
      ann_importer.linked_companies << vendor
    end

    vendor
  end

  def find_factory vendor, factory_segments
    return nil if factory_segments.blank?

    n1 = find_segment factory_segments, "N1"
    id = value(n1, 4)
    system_code = "#{ann_importer.system_code}-MF-#{id}"

    factory = Company.where(factory: true, system_code: system_code).first

    return factory unless factory.nil?

    Lock.acquire(system_code) do
      factory = Company.where(system_code: system_code).first_or_create! name: value(n1, 2), factory: true
      ann_importer.linked_companies << factory
      vendor.linked_companies << factory if vendor
    end

    factory
  end

end; end; end; end