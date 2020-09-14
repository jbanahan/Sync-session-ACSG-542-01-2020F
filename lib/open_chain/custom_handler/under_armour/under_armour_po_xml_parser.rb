require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/custom_handler/under_armour/under_armour_business_logic'

module OpenChain; module CustomHandler; module UnderArmour; class UnderArmourPoXmlParser
  include OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include OpenChain::CustomHandler::UnderArmour::UnderArmourBusinessLogic

  def self.integration_folder
    ["www-vfitrack-net/_ua_po_xml", "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_ua_po_xml"]
  end

  def self.parse_file xml, log, opts = {}
    self.new.parse_file xml, log, opts
  end

  def parse_file xml, log, opts
    dom = REXML::Document.new(xml)
    root = dom.root
    # UA tends to send us blank files for some reason...this checks that and returns if it's blank
    return if root.nil?

    user = User.integration
    root.each_element("Orders") {|order| process_order order, user, opts[:bucket], opts[:key], log }
  end

  def process_order order_xml, user, bucket, file, log
    order_number = order_xml.text "Order"
    revision = order_xml.text("MessageID").to_i

    log.company = importer
    log.error_and_raise "Unable to find Under Armour 'UNDAR' importer account." unless log.company

    product_cache = create_product_cache(order_xml, user, file, log)
    find_or_create_order(order_number, revision, bucket, file) do |order|
      log.add_identifier InboundFileIdentifier::TYPE_PO_NUMBER, order_number, module_type: Order.to_s, module_id: order.id

      # Destroy unshipped lines missing from XML
      line_numbers = xml_line_numbers(order_xml)
      order.order_lines.reject do |ol|
        line_numbers.include?(ol.line_number) || ol.shipment_lines.present?
      end.each(&:destroy)

      process_order_header(order_xml, order)

      order_xml.each_element("OrderDetails") do |detail|
        process_order_detail(order, detail, product_cache)
      end

      order.save!
      order.create_snapshot user, nil, file
    end
  end

  def process_order_header xml, order
    order.order_date = parse_date(xml, "PODate")
    order.terms_of_sale = xml.text "IncoTerm1"
  end

  def process_order_detail order, xml, product_cache
    # Under Armour's system (SAP) sends the prepack line AND all the prepack components as OrderDetails
    # (essentially like sublines).  UA originally told us that they'll only ever have a prepack and
    # nothing else on the PO, however this turned out not to be true.  Multiple prepacks are possible on one
    # PO.  They did say (Feb 2020) that prepack and non-prepack content should not be found on the same PO.
    #
    # Prepack components (i.e. details within a prepack) are not meant to be created as order details.  They
    # can be safely skipped.  We can determine whether or not a detail represents a prepack component by the
    # presence of a ReferenceLine element value.  A prepack component's ReferenceLine will connect back to the
    # prepack it is part of.  Bail out of this method if the current detail is a prepack component.
    prepack_component = xml.text("ReferenceLine").present?
    return if prepack_component

    # For some reason, changes made to records returned by find_or_initialize_by don't get persisted.
    line = order.order_lines.find { |ol| ol.line_number == xml.text("LineNum").to_i }
    line ||= order.order_lines.build line_number: xml.text("LineNum").to_i

    line.quantity = BigDecimal(xml.text("Qty/Quantity").to_s)
    uom = REXML::XPath.first(xml, "Qty/Quantity/@UOM")
    line.unit_of_measure = uom.nil? ? nil : uom.to_s
    line.sku = xml.text "SKU"
    line.price_per_unit = BigDecimal(xml.text("Price/Amount").to_s)
    line.find_and_set_custom_value(cdefs[:ord_line_ex_factory_date], parse_date(xml, "Ex-FactoryDate"))
    line.find_and_set_custom_value(cdefs[:ord_line_division], xml.text("ArticleAttributes/Code[@Type = 'ProductDivision']"))

    prepack = prepack_detail?(xml)
    if prepack
      product_sku = prepack_article_number(line.sku)
    else
      product_sku = line.sku
    end

    product = product_cache[product_sku]
    line.product = product

    if !prepack
      line.variant = product.variants.find {|v| v.variant_identifier == product_sku }
    end
  end

  def find_or_create_order customer_order_number, revision, last_file_bucket, last_file_path
    order_number = "UNDAR-#{customer_order_number}"
    order = nil
    Lock.acquire("Order-#{order_number}") do
      o = Order.where(importer_id: importer.id, order_number: order_number).first_or_create! customer_order_number: customer_order_number
      order = o if process_file?(o, revision)
    end

    if order
      Lock.with_lock_retry(order) do
        return unless process_file?(order, revision)

        order.last_file_bucket = last_file_bucket
        order.last_file_path = last_file_path
        order.find_and_set_custom_value(cdefs[:ord_revision], revision)
        order.find_and_set_custom_value(cdefs[:ord_revision_date], ActiveSupport::TimeZone["America/New_York"].now.to_date)
        yield order
      end
    end

    order
  end

  def create_product_cache order_xml, user, file, log
    variant_products, prepacks, styles = extract_product_details(order_xml)

    products = {}
    styles.each {|s| products[s] = find_or_create_product(s, [], false, user, file, log)}
    variant_products.each_pair do |s, skus|
      product = find_or_create_product(s, skus, false, user, file, log)
      skus.each {|sku| products[sku] = product }
    end

    prepacks.each {|s| products[s] = find_or_create_product(s, [], true, user, file, log)}

    products
  end

  def extract_product_details order_xml
    variant_products = Hash.new {|h, k| h[k] = [] }
    prepacks = []
    styles = []

    REXML::XPath.match(order_xml, "OrderDetails").each do |detail|
      # What we're doing is determining if the order details are prepacks or not...then if the sku matches the standard pattern
      # of UA sku's it means that the 7 digit number is the Article # (.ie Product Part Number) and the full sku is the variant identifier.
      # We'll then find or create variants for each of the full length skus.
      sku = detail.text("SKU")

      # For prepacks or other skus that don't match the standard sku layout, we're just creating the product.
      if prepack_detail?(detail)
        prepacks << prepack_article_number(sku)
      else
        variant_sku = article_number(sku)
        if sku != variant_sku
          variant_products[variant_sku] << sku
        else
          # If the style didn't match the 1231-1231-123 pattern, then just put it in as a plain style
          styles << sku
        end
      end
    end

    [variant_products, prepacks, styles]
  end

  def prepack_detail? order_detail_xml
    order_detail_xml.text("ArticleAttributes/Code[@Type = 'ArticleType']") == "11"
  end

  def find_or_create_product style, skus, prepack, user, file, log
    parts_imp = parts_importer(log)
    unique_identifier = "#{parts_imp.system_code}-#{style}"

    product = nil
    Lock.acquire("Product-#{unique_identifier}") do
      product = Product.where(importer_id: parts_imp.id, unique_identifier: unique_identifier).first_or_initialize

      if !product.persisted?
        product.find_and_set_custom_value(cdefs[:prod_part_number], style)
        product.find_and_set_custom_value(cdefs[:prod_prepack], true) if prepack
      end

      new_variant = false
      skus.each do |sku|
        variant = product.variants.find {|v| v.variant_identifier == sku }
        if variant.nil?
          product.variants.build variant_identifier: sku
          new_variant = true
        end
      end

      if !product.persisted? || new_variant
        product.save!
        product.create_snapshot user, nil, file
      end
    end

    product
  end

  def process_file? order, file_revision
    file_revision >= order.custom_value(cdefs[:ord_revision]).to_i
  end

  def xml_line_numbers order_xml
    REXML::XPath.match(order_xml, "OrderDetails/LineNum").map { |tag| tag.text.to_i }
  end

  def importer
    @importer ||= Company.importers.where(system_code: "UNDAR").first
    @importer
  end

  def parts_importer log
    @parts_system_code ||= MasterSetup.get.custom_feature?("UAPARTS Staging") ? "UAPARTS" : "UNDAR"

    @parts_importer ||= Company.where(system_code: @parts_system_code, importer: true).first
    log.error_and_raise "Unable to find Under Armour '#{@parts_system_code}' importer account." unless @parts_importer
    @parts_importer
  end

  def parse_date parent_element, qualifier
    date_string = parent_element.text("DateTime/Date[@DateQualifier = '#{qualifier}']")

    Date.strptime(date_string, "%Y%m%d") rescue nil # rubocop:disable Style/RescueModifier
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions([:ord_revision, :ord_revision_date, :ord_line_ex_factory_date, :ord_line_division, :prod_part_number, :prod_prepack])
  end

end; end; end; end
