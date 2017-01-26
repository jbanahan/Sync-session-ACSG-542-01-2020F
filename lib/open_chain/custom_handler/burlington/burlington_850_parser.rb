require 'rex12'
require 'open_chain/integration_client_parser'
require 'open_chain/edi_parser_support'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; module Burlington; class Burlington850Parser
  extend OpenChain::IntegrationClientParser
  include OpenChain::EdiParserSupport
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def self.integration_folder
    "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_burlington_po"
  end

  def self.parse data, opts={}
    user = User.integration
    parser = self.new
    REX12::Document.each_transaction(data) do |transaction|
      begin
        parser.process_order(user, transaction.segments, last_file_bucket: opts[:bucket], last_file_path: opts[:key])
      rescue => e
        send_error_email(transaction, e, "Burlington 850", opts[:key])
        e.log_me ["File: #{opts[:key]}"]
      end
    end
  end

  def process_order(user, edi_segments, last_file_bucket:, last_file_path:)
    beg_segment = find_segment(edi_segments, "BEG")
    cancelled = (beg_segment.elements[1].value.to_i == 1)

    # We need to FIRST generate all the products referenced by this PO, this is done outside the main 
    # order transaction because of transactional race-conditions that occur when trying to create products
    # inside the order transaction, resulting in the very real potential to create duplicate products.
    if !cancelled
      # It's a waste of time to lookup and create products on cancelled orders, so don't
      order_line_segments = extract_loop(edi_segments, ["PO1", "CTP", "PID", "PO4", "SAC", "CUR", "SDQ", "SLN", "TC2", "N1", "N2", "N3", "N4", "PER"])
      products = create_products(user, last_file_path, order_line_segments)
    end
    
    find_or_create_order(beg_segment, last_file_bucket, last_file_path) do |order|
      if cancelled
        process_cancelled_order(order, user, last_file_path)
      else
        process_order_header(user, order, edi_segments)

        department = find_department(edi_segments)

        order_line_segments.each do |line_segments|
          process_order_line(order, products, line_segments, department)
        end

        # Destroy any line that is persisted and is not shipping (we built but didn't save brand new lines for all line updates).
        order.order_lines.each do |line|
          line.destroy if line.persisted? && !line.shipping?
        end

        order.save!
        order.create_snapshot user, nil, last_file_path
      end
    end
  end

  def find_department segments
    dept = find_ref_value(segments, "DP")
    case dept.to_s
    when "1"; "Coats"
    when "2"; "Sportswear"
    when "3"; "Kids"
    when "4"; "Mens"
    when "5"; "Acessories"
    when "6"; "Linens"
    when "7"; "Youth"
    when "8"; "Outerwear"
    else 
      nil
    end
  end

  def find_or_create_order beg_segment, last_file_bucket, last_file_path
    cust_order_number = beg_segment.elements[3].value
    revision = beg_segment.elements[4].value.to_i

    order_number = "BURLI-#{cust_order_number}"
    order = nil
    Lock.acquire("Order-#{order_number}") do 
      o = Order.where(order_number: order_number, importer_id: importer.id).first_or_create! customer_order_number: cust_order_number
      order = o if process_file?(o, revision)
    end

    if order
      Lock.with_lock_retry(order) do
        if process_file?(order, revision)
          order.last_file_bucket = last_file_bucket
          order.last_file_path = last_file_path
          order.find_and_set_custom_value(cdefs[:ord_revision], revision)
          # Since virtually everyone that's going to see the revision date is going to see it the US / Eastern Time, set the date relative to that.
          order.find_and_set_custom_value(cdefs[:ord_revision_date], ActiveSupport::TimeZone["America/New_York"].now.to_date)
          yield order
        end
      end
    end
  end

  def process_order_header user, order, edi_segments
    #A pparently, burlington closes orders and then reopens hem if they change from standard lines to prepacks.
    if order.closed?
      order.reopen_logic user
    end

    beg_segment = find_segment(edi_segments, "BEG")

    order.find_and_set_custom_value(cdefs[:ord_type], beg_segment.elements[2].value)
    order.order_date = parse_dtm_date_value(beg_segment.elements[5].value).try(:to_date)

    find_segment(edi_segments, "FOB") do |fob|
      order.terms_of_payment = fob.elements[1].value
      order.terms_of_sale = fob.elements[5].value
    end
    
    order.ship_window_start = find_date_value(edi_segments, "375").try(:to_date)
    order.ship_window_end = find_date_value(edi_segments, "376").try(:to_date)
    order.mode = parse_ship_mode(find_element_value(edi_segments, "TD504"))

    forwarder_segments = extract_n1_loops(edi_segments, qualifier: "FW", stop_segments: "PO1").first

    if forwarder_segments.try(:length) > 0
      # N1 will always be the first segment returned
      order.find_and_set_custom_value(cdefs[:ord_planned_forwarder], forwarder_segments.first.elements[2].value)
    end

    order
  end

  def parse_ship_mode code
    case code.to_s.upcase
    when "A"; "Air"
    when "C"; "Consolidation"
    when "D"; "Parcel Post"
    when "E"; "Expedited Truck"
    when "H"; "Customer Pickup"
    when "L"; "Contract Carrier"
    when "M"; "Motor (Common Carrier)"
    when "O"; "Containerized Ocean"
    when "P"; "Private Carrier"
    when "R"; "Rail"
    when "S"; "Ocean"
    when "T"; "Best Way (Shippers Option)"
    when "U"; "Private Parcel Service"
    when "AE"; "Air Express"
    when "BU"; "Bus"
    when "CE"; "Customer Pickup / Customer's Expense"
    when "LT"; "Less Than Trailer Load (LTL)"
    when "SR"; "Supplier Truck"
    else
      nil
    end
  end

  def process_cancelled_order order, user, filename
    if !order.closed?
      order.close_logic user
      order.save!
      order.create_snapshot user, nil, filename
    end
  end

  def process_order_line order, product_cache, segments, department
    po1 = find_segment(segments, "PO1")
    lines = []
    if prepack? po1
      lines = process_prepack_lines(order, product_cache, segments, department)
    else
      line = process_standard_line(order, product_cache, segments, department)
      lines << line
    end

    lines
  end

  def process_standard_line order, product_cache, segments, department
    po1 = find_segment(segments, "PO1")
    line_number = po1.elements[1].value.to_i
    
    line = find_or_build_order_line order, line_number
    # Line may be nil if the line is already shipping...in that case
    # we do not update the lines
    return nil unless line

    line.quantity = BigDecimal(po1.elements[2].value)
    line.unit_of_measure = po1.elements[3].value
    line.price_per_unit = BigDecimal(po1.elements[4].value)
    style = find_segment_qualified_value(po1, "IT")

    line.product = product_cache[style]
    line.hts = find_element_value(segments, "TC202")
    line.find_and_set_custom_value(cdefs[:ord_line_department_code], department)
    line.find_and_set_custom_value(cdefs[:ord_line_color], find_segment_qualified_value(po1, "BO"))
    line.find_and_set_custom_value(cdefs[:ord_line_size], find_segment_qualified_value(po1, "IZ"))

    find_segments(segments, "CTP") do |ctp|
      case ctp.elements[2].value
      when "ELC"
        line.find_and_set_custom_value(cdefs[:ord_line_estimated_unit_landing_cost], BigDecimal(ctp.elements[3].value))
      when "RTL"
        line.find_and_set_custom_value(cdefs[:ord_line_retail_unit_price], BigDecimal(ctp.elements[3].value))
      end
    end

    line
  end

  def process_prepack_lines order, product_cache, segments, department
    po1 = find_segment(segments, "PO1")
    line_number = po1.elements[1].value.to_i
    sublines = extract_loop(segments, ["SLN", "TC2", "CTP"])

    lines = []
    sublines.each do |subline_segments|
      # Because we're dealing with a subline (and our line_number in order is an integer [bad choice])
      # We're going to make the line number a function of the max number of possible sublines (according to the edi spec, which is 1000)
      sln = find_segment(subline_segments, "SLN")
      tc2 = find_segment(subline_segments, "TC2")

      subline_number = (line_number*1000) + sln.elements[1].value.to_i

      line = find_or_build_order_line order, subline_number
      next if line.nil?

      # In this case, the po1 line is the outer pack quantity and the sln is the # of units per the inner pack
      # (Think of a bag with a bunch of inner bags in it, with each inner bag having a couple items in them)
      # For the PO quantity, we want to know the total # of units that ordered
      order_quantity = BigDecimal(po1.elements[2].value)
      prepack_quantity = BigDecimal(sln.elements[4].value)
      line.quantity = order_quantity * prepack_quantity
      line.price_per_unit = BigDecimal(sln.elements[6].value)
      line.find_and_set_custom_value(cdefs[:ord_line_prepacks_ordered], order_quantity)
      line.find_and_set_custom_value(cdefs[:ord_line_units_per_inner_pack], prepack_quantity)
      line.find_and_set_custom_value(cdefs[:ord_line_department_code], department)
      line.find_and_set_custom_value(cdefs[:ord_line_color], find_segment_qualified_value(sln, "BO"))
      line.find_and_set_custom_value(cdefs[:ord_line_size], find_segment_qualified_value(sln, "IZ"))
      line.find_and_set_custom_value(cdefs[:ord_line_color_description], find_segment_qualified_value(sln, "PU"))

      find_segments(subline_segments, "CTP") do |ctp|
        case ctp.elements[2].value
        when "ELC"
          line.find_and_set_custom_value(cdefs[:ord_line_estimated_unit_landing_cost], BigDecimal(ctp.elements[3].value))
        when "RTL"
          line.find_and_set_custom_value(cdefs[:ord_line_retail_unit_price], BigDecimal(ctp.elements[3].value))
        end
      end

      style = find_segment_qualified_value(sln, "IT")
      line.product = product_cache[style]

      line.hts = find_element_value(subline_segments, "TC202")

      lines << line
    end

    lines
  end

  def find_or_build_order_line order, line_number
    line = order.order_lines.find {|l| l.line_number == line_number}
    if !line.nil?
      return nil if line.shipping?
    end

    order.order_lines.build line_number: line_number
  end

  def create_products user, filename, order_line_segments
    products = {}

    # For prepack lines we're going down to the prepack level for the style
    order_line_segments.each do |segments|
      find_segments(segments, "PO1") do |po1|
        if prepack? po1
          extract_prepack_loops(segments).each do |subline_segments|
            sln = find_segment(subline_segments, "SLN")
            style, product = find_or_create_product(user, filename, sln, find_segment(subline_segments, "TC2"), products)
            products[style] = product if product
          end
        else
          # The way the EDI spec is formulated, the TC2 segment can only be looped under the
          # SLN segment...however, in actual documents, it's sent in the PO1 loop too...bad spec.
          style, product = find_or_create_product(user, filename, po1, find_segment(segments, "TC2"), products)
          products[style] = product if product
        end
      end
    end

    products
  end

  def extract_prepack_loops all_line_segments
    # I'm assuming that what's passed in is only a single PO1 loop's segments.
    extract_loop(all_line_segments, ["SLN", "TC2", "CTP", "SAC", "CUR", "N1", "N2", "N3", "N4", "PER"])
  end

  def find_or_create_product user, filename, style_segment, hts_segment, cache
    style = find_segment_qualified_value(style_segment, "IT")

    return [style, cache[style]] if cache[style]

    description = find_segment_qualified_value(style_segment, "PU").to_s.strip

    hts = hts_segment.elements[2].value.to_s.gsub(".", "") if hts_segment

    product = nil
    unique_identifier = "BURLI-#{style}"
    Lock.acquire("Product-#{unique_identifier}") do
      product = Product.where(unique_identifier: unique_identifier, importer_id: importer.id).first_or_initialize

      unless product.persisted?
        product.find_and_set_custom_value(cdefs[:prod_part_number], style)
        product.save!
      end
    end

    Lock.with_lock_retry(product) do 
      # Don't update descriptions for prepacks, the is because the descriptions include the size and the color
      # which means every prepack with multiple lines will update (and snapshot) the product for every subline.
      product.name = description if product.name.blank? || !(style_segment.segment_type == "SLN")

      cl = nil
      tariff = nil
      if !hts.blank?
        cl = product.classifications.find {|c| c.country_id == us.id }
        if cl.nil?
          cl = product.classifications.build country_id: us.id
        end

        tariff = cl.tariff_records.find {|t| t.line_number == 1 }
        if tariff.nil?
          tariff = cl.tariff_records.build line_number: 1
        end
        tariff.hts_1 = hts
      end

      if product.changed? || cl.try(:changed?) || tariff.try(:changed?)
        product.save!
        product.create_snapshot user, nil, filename
      end
    end

    [style, product]
  end

  def prepack? po1_segment
    po1_segment.elements[3].value.to_s.upcase == "AS"
  end

  def process_file? order, file_revision
    file_revision >= order.custom_value(cdefs[:ord_revision]).to_i
  end

  def cdefs
    @cd ||= self.class.prep_custom_definitions([:ord_revision, :ord_revision_date, :ord_type, :ord_planned_forwarder, :ord_line_prepacks_ordered, :ord_line_retail_unit_price, :ord_line_estimated_unit_landing_cost, :ord_line_department_code, :ord_line_size, :ord_line_color, :ord_line_units_per_inner_pack, :ord_line_color_description, :prod_part_number])
  end

  def importer
    @importer ||= Company.importers.where(system_code: "BURLI").first
    raise "Unable to find Burlington importer account with system code of: 'BURLI'." unless @importer

    @importer
  end

  def us
    @country ||= Country.where(iso_code: "US").first
    raise "No 'US' country configured." unless @country

    @country
  end

end; end; end; end;