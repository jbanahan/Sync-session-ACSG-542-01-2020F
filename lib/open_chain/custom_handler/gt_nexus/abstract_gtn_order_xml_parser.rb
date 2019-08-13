require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/custom_handler/gt_nexus/generic_gtn_parser_support'

# This class is meant to be extended for customer specific Order loads in the GT Nexus 
# order xml format.
#
# By default, the parse handles finding / creating all orders, products, parties listed in the order
# and provides simple overridable methods to use to extend the base information extracted from the xml
# for the Order, OrderLine, Product, and Company records it generates.
# 
# Additionally some configuration values can be set by a constructor.
#
# The bare minimum that must be done to extend this class is to implement the following methods:
# 
# - initialize - Your initialize method must call super and pass a configuration hash.  If you want to 
# stick with the defaults, pass a blank hash.  See initialize below to see the configuration options available.
# - importer_system_code
# - party_system_code
# - import_country.
#
# Additional methods of interest provided for ease of adding customer specific values are:
# 
# - set_additional_order_information
# - set_additional_order_line_information
# - set_additional_party_information
# - set_additional_product_information
#
#
module OpenChain; module CustomHandler; module GtNexus; class AbstractGtnOrderXmlParser
  include OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include OpenChain::CustomHandler::GtNexus::GenericGtnParserSupport

  # Sets any additional customer specific information into the order.
  # in the generic case, this method is a no-op
  def set_additional_order_information order, order_xml
    # This is an extension point..by default it's left blank
  end

  # Sets any customer specific information into the order line provided.
  def set_additional_order_line_information order, order_line, item_xml
    # This is an extension point..by default it's left blank
  end

  def set_additional_party_information company, party_xml, party_type
    # This is an extension point for adding customer specific data to a party.
    # For instance, adding the MID for a factory that is sent with customer specific identifiers
  end

  def set_additional_product_information product, order_xml, line_xml
    # This is an extension point to set any customer specific reference values.
    # If ANY reference value is updated, your implementation of the method MUST return true
    false
  end

  # Return the system code to utilize on the purchase orders.
  # It's possible that the same GT Nexus account may map to multiple of our importers,
  # ergo the need to pass the order xml.
  # This method is called once at the beginning of parsing the XML and never again.
  def importer_system_code order_xml
    inbound_file.error_and_raise "Your customer specific class extension must implement this method, returning the system code of the importer to utilize on the Orders."
  end

  # Return the system code to use for the party xml given.  
  # DO NOT do any prefixing (like w/ the importer system code), the caller will handle all of that
  # for you.  Just return the identifying information for the party using the provided XML party element.
  def party_system_code party_xml, party_type
    # I'm pretty sure in the vast majority of cases we should be using customer specific identifiers
    # inside the identification element...those appear to be 100% customer specific though and not 
    # generic, so we'll have to have this be overriden to determine which internal code in the party object should
    # be used in all cases.
    inbound_file.error_and_raise "This method must be overriden by an implementing class."
  end

  # Given an orderDetail / orderItem xml element determines the import country to utilize when setting an hts 
  # value on a given product.
  # Return nil if the tariff number shouldn't be set.
  #
  # This method does not have to be implemented if the set_product_hts_numbers configuration option is set to false.
  def import_country order_xml, item_xml
    inbound_file.error_and_raise "This method must be overridden by an implementing class"
  end

  def initialize configuration
    # In general, you'll want to set this to false on customer specific systems (ll, polo, etc)
    @prefix_identifiers_with_system_codes = configuration[:prefix_identifiers_with_system_codes].nil? ? true : configuration[:prefix_identifiers_with_system_codes]

    # In the general case, we're not exploding prepacks onto the PO, we're going to be just handling the lines
    # as they are sent at the top level orderItem elements
    # If explode prepacks is true, then we will handle the nested orderItem elements 
    @explode_prepacks = configuration[:explode_prepacks].nil? ? false : configuration[:explode_prepacks]

    if should_explode_prepacks?
      inbound_file.error_and_raise "Because there has been no customer yet who needs us to explode GTN prepacks, no testing has been done yet on exploding GTN prepacks.  Please thoroughly evaluate the prepack codepaths before continuing, and then remove this error."
    end

    @delete_unreferenced_lines = configuration[:delete_unreferenced_lines].nil? ? true : configuration[:delete_unreferenced_lines]

    # Sometimes the HTS numbers on the given PO should not be utilized in the product library, in this case, set this configuration option
    # to false to skip them.  HTS will be recorded at the order line regardless of this setting.
    @set_product_hts_numbers = configuration[:set_product_hts_numbers].nil? ? true : configuration[:set_product_hts_numbers]
  end


  def should_explode_prepacks?
    @explode_prepacks
  end

  def prefix_identifiers_with_system_codes?
    @prefix_identifiers_with_system_codes
  end

  def delete_unreferenced_lines?
    @delete_unreferenced_lines
  end

  def set_product_hts_numbers?
    @set_product_hts_numbers
  end

  def self.parse_file data, log, opts = {}
    xml = REXML::Document.new(data)

    user = User.integration

    # I don't believe GTN actually exports multiple PO's per XML document, they use the
    # same schema for uploading to them and downloading from them, so the functionality is 
    # there to send them mulitple PO's, but as to getting them exported to us on event triggers,
    # I don't think we get more than one per XML document
    REXML::XPath.each(xml.root, "/Order/orderDetail") do |order|
      self.process_order(order, user, opts[:bucket], opts[:key])
    end

  end

  # Process a single orderDetail order element from the file
  def self.process_order xml, user, bucket, key
    parser = self.new

    if parse_function_code(xml) == :cancel
      return parser.process_order_cancel xml, user, bucket, key
    else
      return parser.process_order_update xml, user, bucket, key
    end
  end

  # Determine the type of processing to do for the order, cancel or update
  def self.parse_function_code xml
    function_code = xml.text("orderFunctionCode").to_s
    if (function_code =~ /Delete/i) || (function_code =~ /Cancel/i)
      return :cancel
    else
      return :update
    end
  end

  # Cancels an order.
  def process_order_cancel xml, user, bucket, key
    order_number = order_number(xml)
    set_importer_system_code(xml)
    
    order = Order.where(order_number: prefix_identifier_value(importer, order_number), importer_id: importer.id).first
    return unless order

    revision_time = order_revision(xml)

    o = nil
    Lock.db_lock(order) do
      if process_file? order, revision_time
        o = order
        set_order_file_metadata order, revision_time, bucket, key

        if !order.closed?
          order.close_logic user
        end

        order.save!
        order.create_snapshot user, nil, key
      end
    end

    o
  end

  # Updates or creates an order
  def process_order_update xml, user, bucket, key
    o = nil
    set_importer_system_code(xml)
    parties = parse_parties(xml, user, key)
    products = create_product_cache(xml, user, key)

    find_or_create_order(xml, bucket, key) do |order|
      set_parties(order, parties)
      set_order_information(order, xml)
      parse_order_lines(order, xml, products)

      order.save!
      order.create_snapshot user, nil, key
      o = order
    end

    o
  end

  # Finds or creates the order, sets some basic information and then yields the order.
  # 
  # If we determine from the order revision number that the order should not be processed,
  # then no order object is yielded to the caller.
  def find_or_create_order order_xml, bucket, key
    order = nil
    order_number = order_number(order_xml)
    revision_time = order_revision(order_xml)

    unique_identifier = prefix_identifier_value(importer, order_number)
    Lock.acquire("Order-#{unique_identifier}") do
      o = Order.where(importer_id: importer.id, order_number: unique_identifier).first_or_create!
      if process_file?(o, revision_time)
        order = o
      end
    end
    
    if order
      Lock.db_lock(order) do 
        if process_file?(order, revision_time)
          order.customer_order_number = order_number
          inbound_file.add_identifier :po_number, order_number, module_type: Order, module_id: order.id
          set_order_file_metadata order, revision_time, bucket, key

          yield order
        else
          order = nil
        end
      end
    end

    order
  end

  # Sets basic metadata about the xml file into the order
  def set_order_file_metadata order, revision_time, bucket, key
    order.last_exported_from_source = revision_time
    order.last_file_path = key
    order.last_file_bucket = bucket
    nil
  end

  # Determines whether or not to process the file based on the revision number given in the xml.
  def process_file? order, revision_time
    order.last_exported_from_source.nil? || order.last_exported_from_source <= revision_time
  end

  # Sets all the basic order level information that's being tracked from GTN
  # This method calls the following extension hooks: set_order_terms_reference_values, set_addition_order_information
  def set_order_information order, xml
    order.customer_order_status = xml.text "orderStatusCode"
    order.find_and_set_custom_value(cdefs[:ord_type], xml.text("orderClassType"))
    order.find_and_set_custom_value(cdefs[:ord_country_of_origin], xml.text("party[partyRoleCode = 'OriginOfGoods']/address/countryCode"))
    order.find_and_set_custom_value(cdefs[:ord_destination_code], xml.text("party[partyRoleCode = 'ShipmentDestination']/reference[type = 'UNLocode']/value"))
    order.find_and_set_custom_value(cdefs[:ord_buyer], xml.text("party[partyRoleCode = 'Buyer']/contact/name"))

    terms = xml.elements["orderTerms"]
    if terms
      order.mode = terms.text "shipmentMethodCode"
      order.terms_of_sale = terms.text "incotermCode"
      order.fob_point = terms.text "incotermLocationCode"
      order.currency = terms.text "currencyCode"
      order.order_date = date_value(terms, "Issue")
    end
    
    set_additional_order_information order, xml
    nil
  end

  # Extracts the corresponding orderDateValue from an orderDate element given the specified orderDateTypeCode
  def date_value date_parent, code
    date = nil
    val = date_parent.text "orderDate[orderDateTypeCode = '#{code}']/orderDateValue"
    if !val.blank?
      date = Date.iso8601(val) rescue nil
    end
    date
  end

  # Processes all the order lines
  def parse_order_lines order, order_xml, product_cache
    referenced_order_lines = []
    each_order_line(order_xml) do |item_xml|
      # Potentially we could allow multiple order lines per orderItem element, so also allow for this here
      lines = parse_order_line(order, item_xml, product_cache)
      Array.wrap(lines).each {|line| referenced_order_lines << line }
    end

    if delete_unreferenced_lines?
      delete_lines order, referenced_order_lines
    end

    nil
  end

  # Deletes all order lines that can be deleted (.ie that are not shipped/booked) that
  # are NOT included in the referenced_order_lines parameter.
  # 
  # Deletions are determine based on the line_number of the referenced_order_lines.
  def delete_lines order, referenced_order_lines
    line_numbers = Set.new referenced_order_lines.map(&:line_number)
    undeleted_lines = []
    order.order_lines.each do |line|

      if !line_numbers.include?(line.line_number)
        # We need to check if the line is booking or shipping.  If it is, then we
        # can't delete it.  We'll just leave any line that can't be deleted around.
        if line.can_be_deleted?
          line.destroy
        else
          # For the moment, not going to do anything with this.  When we have logging enabled,
          # the line numbers for the undeleted lines should be recorded in a warning.
          undeleted_lines << line
        end
      end
    end
    nil
  end

  # Simple method that yields each orderItem element based on if we're expecting prepacks or not.
  def each_order_line order_xml
    REXML::XPath.each(order_xml, "orderItem") do |line_xml|
      yield line_xml
    end
  end

  # Extracts the baseItem element from an orderItem element
  def base_item_element line_xml
    line_xml.elements["baseItem"]
  end

  # Parses a top-level orderItem element into 1 or more order lines
  def parse_order_line order, item_xml, product_cache
    lines = []
    if explode_prepacks?(item_xml)
      REXML::XPath.each(item_xml, "orderItem") do |prepack_xml|
        line = parse_prepack_order_line order, prepack_xml, product_cache
        lines.push *Array.wrap(line) if line
      end
    else
      line = parse_standard_order_line order, item_xml, product_cache
      lines.push *Array.wrap(line) if line
    end

    lines
  end

  # Returns true if we should explode the given top level orderItem element into component prepacks or not
  def explode_prepacks? item_xml
    return should_explode_prepacks? && has_prepack_lines?(item_xml)
  end

  # Returns true if the given top-level orderItem has sub-prepack lines.
  def has_prepack_lines? item_xml
    # I'm not entirely sure how this should work since I haven't seen any XML from customer where we explode out prepacks.
    # For the moment, I'm just going to see if there are any orderItem element below the given top level one, and if so,
    # that will indicate that there is a prepack or not.
    item_xml.elements["orderItem"].try(:length).to_i > 0
  end

  # Parses an orderItem and turns it into an OrderLine
  # The basic handling of associating the style w/ the product and creating/updating lines is done here
  # You can override the set_additional_order_line_information to parse any additional customer specific
  # line level information.
  def parse_standard_order_line order, item_xml, product_cache
    line_number = item_xml.text("itemKey").to_i
    base_item = base_item_element(item_xml)

    inbound_file.reject_and_raise("All orderDetail elements are expected to have itemKey values.") unless line_number > 0
    part_number = order_item_part_number base_item
    unique_identifier = product_unique_identifier part_number

    order_line = order.order_lines.find {|l| l.line_number == line_number }
    if order_line.nil?
      order_line = order.order_lines.build line_number: line_number
    else
      # If we're updating a line that's booked or shipping, we cannot change the product on it..any other information is ok to change.
      existing_part_number = order_line.product.custom_value(cdefs[:prod_part_number])
      if order_line.booked? || order_line.shipping?
        inbound_file.reject_and_raise("Order Line # #{order_line.line_number} with Part Number #{existing_part_number} is already associated with a shipment.  The part number cannot be changed to #{part_number}.") if part_number != existing_part_number
      end
    end

    order_line.product = product_cache[unique_identifier]
    inbound_file.reject_and_raise("Failed to find associated product for #{part_number}") if order_line.product.nil?

    set_order_line_information order, order_line, item_xml
    set_additional_order_line_information order, order_line, item_xml

    order_line
  end

  # Parses an orderItem and turns it into an OrderLine
  # The basic handling of associating the style w/ the product and creating/updating lines is done here
  # You can override the set_additional_order_line_information to parse any additional customer specific
  # line level information.
  def parse_prepack_order_line order, item_xml, product_cache
    # We don't have anyone that's actually doing prepack handling w/ GTN orders...so for the moment,
    # lets just assume that prepacks will work just like standard lines, but just work on the lower-level
    # orderItem/orderItem element rather than the top level orderItem one.
    parse_standard_order_line(order, item_xml, product_cache)
  end

  # Returns the part number associated with the given orderItem/baseItem element
  def order_item_part_number base_item_xml
    # Not sure if this is the actual part number by default on a GTN order xml feed.
    part_number = item_identifier_value(base_item_xml, "BuyerNumber") if base_item_xml
    inbound_file.reject_and_raise("All orderDetail elements are expected to have BuyerNumber values.") if part_number.blank?
    part_number
  end

  # Sets basic information about the line: quantity, uom, hts, price
  def set_order_line_information order, order_line, item_xml
    base_item = base_item_element(item_xml)

    order_line.quantity = BigDecimal(base_item.text("quantity").to_s)
    order_line.unit_of_measure = base_item.text "unitOfMeasureCode"
    order_line.price_per_unit = BigDecimal(item_xml.text("itemPrice/pricePerUnit").to_s)
    order_line.hts = base_item.text "customsClassification/classificationNumber"

    nil
  end


  # A mapping of party type to XPath expression of how to extract the party element for a particular type.
  # By default, vendor and factory are mapped to the order.
  #
  # Extending classes can override this...the keys MUST be the company attribute to set to true to 
  # denote a particular company type (vendor, factory, etc).  The values must be the XPath to find the party
  # element based from the party elements parent (orderDetail element in most cases)
  def party_map  
    {vendor: "party[partyRoleCode = 'Seller']", factory: "party[partyRoleCode = 'OriginOfGoods']"}
  end

  # All custom definition uids required for logic needed in the generic order parser code.
  def generic_cdef_uids
    c = [:ord_type, :ord_buyer, :ord_country_of_origin, :ord_destination_code]
    if prefix_identifiers_with_system_codes?
      c << :prod_part_number
    end
    c
  end

  # Extracts the order number from the orderDetail element
  def order_number order_xml
    order_xml.text "poNumber"
  end

  # Extracts the revision number from the orderDetail element
  def order_revision order_xml
    time = time_zone.parse(order_xml.text("revisionNumber")) rescue nil
    inbound_file.reject_and_raise("All GT Nexus Order documents must have a revisionNumber that is a valid timestamp.") if time.nil?
    time
  end

  # Loops through all top level orderItem elements (descending to prepacks if required) and finds or creates (and updates if required)
  # all references products.
  def create_product_cache order_xml, user, filename
    cache = {}
    products_to_snapshot = {}
    each_order_line(order_xml) do |line_xml|
      needs_snapshot = false

      if explode_prepacks?(line_xml)
        REXML::XPath.each(item_xml, "orderItem") do |prepack_xml|
          product, needs_snapshot = find_or_create_prepack_product(order_xml, prepack_xml, cache)
          products_to_snapshot[product.unique_identifier] = product if product && needs_snapshot
          cache[product.unique_identifier] = product
        end
      else
        product, needs_snapshot = find_or_create_standard_product(order_xml, line_xml, cache)
        products_to_snapshot[product.unique_identifier] = product if product && needs_snapshot
        cache[product.unique_identifier] = product
      end
    end    

    products_to_snapshot.values.each {|product| product.create_snapshot user, nil, filename }

    cache
  end

  # Finds, creates, updates the product referenced on the given orderItem element
  def find_or_create_standard_product order_xml, line_xml, product_cache
    base_item = base_item_element(line_xml)
    style = order_item_part_number(base_item)
    product, created = find_or_create_product(style, product_cache)

    updated = false
    Lock.with_lock_retry(product) do
      if update_standard_product(product, order_xml, line_xml)
        updated = true
        product.save!
      end
    end

    [product, (created || updated)]
  end

  # Finds, creates, updates the prepack product referenced on the given orderItem element
  def find_or_create_prepack_product order_xml, line_xml, product_cache
    # I don't know enough about how GTN works with prepacks, etc and since we don't have
    # a customer sending us prepack information we need to handle atm I'm just going to 
    # assume it can be handle exactly like a standard product, just at the lower orderItem/orderItem
    # level, rather than the top level orderItem one
    find_or_create_standard_product(order_xml, line_xml, product_cache)
  end

  # Given a product, sets all basic information about it found on the given orderItem element
  # Method MUST track changes and return true if the product is to be saved or not.
  # Base attributes set are the name and hts.
  # Calls set_additional_product_information as an extension point for any customer specific data that must
  # be parsed from the data.
  def update_standard_product(product, order_xml, line_xml)
    changed = MutableBoolean.new false
    base_item = base_item_element(line_xml)
    product.name = item_descriptor_value(base_item, "LongDescription")
    
    if set_product_hts_numbers?
      hts = base_item.text("customsClassification/classificationNumber")
      if !hts.blank?
        country = import_country(order_xml, line_xml)
        if !country.nil?
          existing_tarifff = product.hts_for_country(country).first
          if hts != existing_tarifff
            product.update_hts_for_country(country, hts)
            changed.value = true
          end
        end
      end
    end
    
    references_updated = set_additional_product_information(product, order_xml, line_xml)

    changed.value || product.changed? || references_updated
  end

  # Finds a product or creates it given a style...handles setting the importer system code or not based on the 
  # prefix_identifiers_with_system_codes configuration setting.
  def find_or_create_product style, product_cache
    # All we're really doing here is setting up the basic information like style and then
    # we'll rely on the callback we issue after locking the product row to update all other information
    product = nil
    created = false

    unique_identifier = product_unique_identifier(style)
    product = product_cache[unique_identifier]
    
    if product.nil?
      Lock.acquire("Product-#{unique_identifier}") do 
        product = Product.where(unique_identifier: unique_identifier, importer_id: importer.id).first_or_initialize

        unless product.persisted?
          created = true
          # If we're prefixing identifiers, it means that we're tracking the part number separately w/ a custom value too, so make sure to set it.
          product.find_and_set_custom_value(cdefs[:prod_part_number], style) if prefix_identifiers_with_system_codes?
          product.save!
        end
      end
    end

    [product, created]
  end

  # Returns the unique identifier value to use based on if part number prefixing is required or not.
  def product_unique_identifier style
    prefix_identifier_value(importer, style)
  end

  # Prefixes the given value with the provided company's system code if the prefix_identifiers_with_system_codes
  # configuration option is set to true (default == true)
  def prefix_identifier_value company, value
    prefix_identifiers_with_system_codes? ? "#{company.system_code}-#{value}" : value
  end

end; end; end; end