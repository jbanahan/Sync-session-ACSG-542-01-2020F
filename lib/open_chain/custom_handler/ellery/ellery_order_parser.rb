require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; module Ellery; class ElleryOrderParser
  extend OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def self.integration_folder 
    ["www-vfitrack-net/_ellery_po", "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_ellery_po"]
  end

  def self.parse_file data, log, opts = {}
    # This should be a standard CSV file.
    po_number = nil
    rows = []
    parser = parser_instance

    log.company = parser.importer

    CSV.parse(data) do |row|
      local_po = row[11]
      next if local_po.blank?

      if local_po != po_number && rows.length > 0
        parser.process_order rows, log, bucket: opts[:bucket], key: opts[:key]
        rows = []
        po_number = local_po
      end
    
      po_number = local_po
      rows << row
    end

    parser.process_order(rows, log, bucket: opts[:bucket], key: opts[:key]) if rows.length > 0
    nil
  end

  def self.parser_instance
    self.new
  end

  def process_order rows, log, bucket:, key:
    user = User.integration

    first_row = rows.first
    vendor = find_or_create_vendor(first_row, importer)
    ship_to = find_or_create_ship_to(first_row, importer)
    products = find_or_create_products(rows, importer, user, key)

    find_or_create_order(first_row, importer, log, bucket, key) do |order, new_order|
      order.vendor = vendor
      order.ship_to = ship_to
      process_order_header(order, first_row)

      lines = []
      rows.each do |row|
        lines << process_order_line(order, row, products)
      end

      # Delete any lines that aren't reference in the file being parsed (unless they're on a booking / shipment)
      order.order_lines.each do |line|
        line.mark_for_destruction unless lines.include?(line) || line.shipping? || line.booked?
      end

      fingerprint_and_save_order(order, user, key)
    end
  rescue => e
    raise e unless Rails.env.production?

    e.log_me ["File: #{key}"]
  end

  def fingerprint_and_save_order order, user, file
    # Ellery sends us literally their whole list of open orders daily...we do not want to save these
    # orders every single day and generate tons of extra history/snapshot records for no reason.
    # So, we're creating a fingerprint of the data in the order and then only saving if the order data
    # actually changed.
    fingerprint = order.generate_fingerprint(fingerprint_descriptor, user)
    xref_fingerprint = DataCrossReference.find_po_fingerprint order

    save = false
    if xref_fingerprint.nil?
      DataCrossReference.create_po_fingerprint order, fingerprint
      save = true
    else
      if fingerprint != xref_fingerprint.value
        save = true
        xref_fingerprint.value = fingerprint
        xref_fingerprint.save!
      end
    end

    if save
      order.save!
      order.create_snapshot user, nil, file
      true
    else
      false
    end
  end


  def process_order_header order, row
    # NOTE: Any new fields added should also be added to the fingerprint arrays below
    order.find_and_set_custom_value cdefs[:ord_division], row[0]
    order.find_and_set_custom_value cdefs[:ord_destination_code], row[1]
    order.customer_order_number = row[11]
    order.order_date = parse_date row[12]
    order.ship_window_end = parse_date row[13]
    order.currency = row[20]
    order.fob_point = row[21]
    order.mode = row[22]
    order.find_and_set_custom_value cdefs[:ord_ship_type], row[23]
    order.find_and_set_custom_value cdefs[:ord_buyer], row[24]
    order.terms_of_payment = row[25]
    order.find_and_set_custom_value cdefs[:ord_customer_code], row[29]
    order.find_and_set_custom_value cdefs[:ord_buyer_order_number], row[46]
  end

  def fingerprint_descriptor
    {
      model_fields: order_header_fingerprint_fields(),
      order_lines: {
        model_fields: order_line_fingerprint_fields()
      }
    }
  end

  def cd v
    cdefs[v].model_field_uid
  end

  def order_header_fingerprint_fields
    [
      :ord_imp_id, :ord_ven_id, :ord_ship_to_id, :ord_ord_num, cd(:ord_division), cd(:ord_destination_code),
      :ord_cust_ord_no, :ord_ord_date, :ord_window_end, :ord_currency, :ord_fob_point, :ord_mode, 
      cd(:ord_ship_type), cd(:ord_buyer), :ord_payment_terms, cd(:ord_customer_code), cd(:ord_buyer_order_number)
    ]
  end


  def process_order_line order, row, products
    # As near as I can tell, Ellery doesn't have duplicate UPC's on the order...what
    # they do though is "close out" a line once it's partially shipped and then 
    # re-open the line on the same order as another line.  We don't want to duplicate
    # that functionality.  They also totally close out every existing line and then
    # replace them all.  We can't replicate that due to how we connect orders to shipments.
    # Instead, just find the existing lines by UPC and update them that way.
    sku = row[28]
    line = order.order_lines.find {|l| l.sku == sku }
    if line.nil?
      # We're also purposely NOT using the line numbers from Ellery, as they'll change
      # progressively as new edits to the order are made.
      line = order.order_lines.build
    end
    
    # NOTE: Any new fields added should also be added to the fingerprint arrays below
    line.product = products[row[27]]
    line.sku = sku
    line.find_and_set_custom_value cdefs[:ord_line_size], row[31]
    line.find_and_set_custom_value cdefs[:ord_line_color], row[32]
    line.find_and_set_custom_value cdefs[:ord_line_division], row[35]
    line.find_and_set_custom_value cdefs[:ord_line_units_per_inner_pack], row[40].to_i
    line.hts = row[41].to_s.gsub(".", "")
    line.find_and_set_custom_value cdefs[:ord_line_planned_available_date], parse_date(row[42])
    line.price_per_unit = BigDecimal(row[43].to_s) 
    line.quantity = BigDecimal(row[44].to_s)

    line
  end


  def order_line_fingerprint_fields
    [
      :ordln_prod_db_id, :ordln_sku, cd(:ord_line_size), cd(:ord_line_color), cd(:ord_line_division), cd(:ord_line_units_per_inner_pack), :ordln_hts, 
      cd(:ord_line_planned_available_date), :ordln_ppu, :ordln_ordered_qty
    ]
  end

  def find_or_create_order row, importer, log, last_file_bucket, last_file_path
    po = row[11].to_s.strip
    order_number = "#{importer.system_code}-#{po}"

    order = nil
    created = false
    Lock.acquire("Order-#{order_number}") do 
      order = Order.where(importer_id: importer.id, order_number: order_number).first_or_initialize

      if !order.persisted?
        created = true
        order.save!
      end

      log.add_identifier InboundFileIdentifier::TYPE_PO_NUMBER, po, module_type:Order.to_s, module_id:order.id
    end

    if order
      Lock.db_lock(order) do
        order.last_file_bucket = last_file_bucket
        order.last_file_path = last_file_path

        yield order, created
      end
    end

    nil
  end

  def find_or_create_products rows, importer, user, last_file_path
    product_cache = {}

    rows.each do |row|
      part_number = row[27]

      next unless product_cache[part_number].nil?

      product_cache[part_number] = find_or_create_product(row, part_number, importer, user, last_file_path)
    end

    product_cache
  end

  def find_or_create_product row, part_number, importer, user, last_file_path
    unique_identifier = "#{importer.system_code}-#{part_number}"
    product = nil
    created = false
    Lock.acquire("Product-#{unique_identifier}") do
      product = Product.where(unique_identifier: unique_identifier, importer_id: importer.id).first_or_initialize

      if !product.persisted?
        created = true
        product.save!
      end
    end

    Lock.db_lock(product) do
      update_product(row, product, created, user, last_file_path)
    end

    product
  end

  def update_product row, product, new_product, user, last_file_path
    # I'm not going to update product data, except when a new part comes in.

    # The ONLY exception is going to be the HTS number, we'll update that whenever it changes
    if new_product
      product.name = row[30]
      product.find_and_set_custom_value cdefs[:prod_part_number], row[27]
      product.find_and_set_custom_value cdefs[:prod_class], row[36]
      product.find_and_set_custom_value cdefs[:prod_product_group], row[37]

      product.save!
    end

    hts_updated = false
    hts = row[41].to_s.gsub(".", "")
    if new_product
      product.update_hts_for_country us, hts
    else
      existing_hts = product.hts_for_country(us).first
      if hts != existing_hts
        product.update_hts_for_country us, hts
        hts_updated = true
      end
    end

    if hts_updated || new_product
      product.create_snapshot user, nil, last_file_path
    end
    
  end

  def find_or_create_vendor row, importer
    vendor_code = row[2]
    @vendors ||= {}
    vendor_system_code = "#{importer.system_code}-#{vendor_code}"

    vendor = @vendors[vendor_system_code]
    return vendor unless vendor.nil?

    created = false
    Lock.acquire("Company-#{vendor_system_code}") do 
      vendor = Company.vendors.where(system_code: vendor_system_code).first_or_initialize name: row[3]
      if !vendor.persisted?
        created = true
        vendor.save!
      end
    end

    # We're going to assume that if the vendor name is blank, then the rest of the data
    # for the vendor needs to be set
    if vendor && created
      Lock.db_lock(vendor) do
        a = vendor.addresses.build
        a.system_code = vendor.system_code
        a.line_1 = row[4]
        a.line_2 = row[5]
        a.line_3 = row[6]
        a.city = row[7]
        a.state = row[8]
        a.postal_code = row[9]
        a.country = find_country(row[10])

        vendor.save!
        importer.linked_companies << vendor
      end
    end

    @vendors[vendor_system_code] = vendor
  end

  def find_or_create_ship_to row, importer
    @addresses ||= {}
    name = row[14]

    address = @addresses[name]
    return address unless address.nil?
    
    created = false
    Lock.acquire("Address-#{name}") do 
      address = Address.where(company_id: importer.id, name: row[14]).first_or_initialize
      if !address.persisted?
        created = true
        address.save!
      end
    end
    
    if address && created
      Lock.db_lock(address) do
        address.line_1 = row[15]
        address.city = row[16]
        address.state = row[17]
        address.postal_code = row[18]
        address.country = find_country(row[19])

        address.save!
      end
    end

    @addresses[name] = address
  end

  def find_country code
    # Ellery sends 3 char country codes (which is fine)...but they don't send standard ones
    #...just do the best we can with what they give us and fix bad translations based on some test file data
    translations = {"CHI" => "CHN"}
    if translations[code]
      code = translations[code]
    end

    @countries ||= Hash.new do |h, k|
      h[k] = Country.where(iso_3_code: k).first
    end

    @countries[code]
  end

  def user
    @user ||= User.integration
  end

  def importer
    @importer ||= Company.importers.where(system_code: "ELLHOL").first
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions [
      :prod_part_number, :prod_product_group, :prod_class, 
      :ord_division, :ord_destination_code, :ord_ship_type, :ord_buyer, :ord_customer_code, :ord_buyer_order_number, 
      :ord_line_size, :ord_line_color, :ord_line_division, :ord_line_units_per_inner_pack, :ord_line_planned_available_date
    ]
  end

  def us
    @us ||= find_country("USA")
  end

  def parse_date d
    Date.strptime d, "%Y%m%d"
  rescue
    nil
  end

end; end; end; end