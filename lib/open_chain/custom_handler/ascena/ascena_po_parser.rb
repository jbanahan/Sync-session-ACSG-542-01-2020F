require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; module Ascena; class AscenaPoParser
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  extend OpenChain::IntegrationClientParser
  attr_accessor :importer, :user, :cdefs, :errors

  CDEF_LABELS = [ :ord_line_season, :ord_buyer,:ord_division,:ord_revision, :ord_revision_date, :ord_assigned_agent,
                  :ord_selling_agent, :ord_selling_channel, :ord_type, :ord_line_color, :ord_line_color_description,
                  :ord_line_department_code,:ord_line_destination_code, :ord_line_size_description,:ord_line_size,
                  :ord_line_wholesale_unit_price, :ord_line_estimated_unit_landing_cost,:prod_part_number,
                  :prod_product_group,:prod_vendor_style ]

  def initialize
    @user = User.integration
    @importer = Company.where(system_code: "ASCENA").first_or_create!(name:'ASCENA TRADE SERVICES LLC',importer:true)
    @errors = {missing_shipped_order_lines: []}
  end

  def self.integration_folder
    "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_ascena_po"
  end

  def self.parse pipe_delimited_content, opts={}
    self.new.process_file(pipe_delimited_content, opts)
  end

  def process_file(pipe_delimited_content, opts={})
    # Initialize the fields only when needed - primarily this just speeds up unit tests
    @cdefs ||= self.class.prep_custom_definitions CDEF_LABELS

    po_rows = []
    begin
      CSV.parse(pipe_delimited_content, csv_options) do |row|
        next if blank_row?(row)
        if(row[0] == 'H')
          if po_rows.length > 0
            process_po(po_rows, opts)
            po_rows = []
          end
        end
        po_rows << row
      end
      process_po(po_rows, opts) if po_rows.length > 0
    rescue => e
      raise e unless Rails.env.production?
      # Log the error and don't bother attempting to reprocess the file...by adding the file path into the error,
      # we can always reproc when the error email is received if the error warrants it.
      e.log_me ["Ascena PO File #{opts[:key]}"]
    end
  end

  def date_parse str
    date = Date.strptime(str, "%m%d%Y") rescue nil
    (date && date.year < 2000) ? nil : date
  end

  def blank_row? row
    return true if row.blank?
    row.find {|c| !c.blank? }.nil?
  end

  def self.validate_header header
    raise "Customer order number missing" if header[:ord_customer_order_number].blank?
  end

  def self.validate_detail detail, row_num
    raise "Part number missing on row #{row_num}" if detail[:prod_part_number].blank?
    raise "Quantity missing on row #{row_num}" if detail[:ordln_quantity].blank?
    raise "Line number missing on row #{row_num}" if detail[:ordln_line_number].nil? || detail[:ordln_line_number].zero?
  end


  def self.map_header row
    hsh = {}
    hsh[:ord_order_date] = row[1]
    hsh[:ord_line_department_code] = row[2]
    hsh[:ord_customer_order_number] = row[4]
    hsh[:ordln_destination_code] = row[5]
    hsh[:ord_selling_channel] = row[7]
    hsh[:prod_product_group] = row[8]
    hsh[:ord_division] = row[9]
    hsh[:ordln_season] = row[10]
    hsh[:ord_revision] = row[12]
    hsh[:ord_revision_date] = row[13]
    hsh[:ord_vend_system_code] = row[14]
    hsh[:ord_vend_name] = row[15]
    hsh[:ord_assigned_agent] = row[16]
    hsh[:ord_fact_system_code] = row[17]
    hsh[:ord_fact_mid] = row[18]
    hsh[:ord_fact_name] = row[19]
    hsh[:ord_selling_agent] = row[20]
    hsh[:ord_buyer] = row[21]
    hsh[:ord_terms_of_sale] = row[22]
    hsh[:ordln_country_of_origin] = row[23]
    hsh[:ord_mode] = row[24]
    hsh[:ord_ship_window_start] = row[25]
    hsh[:ord_ship_window_end] = row[26]
    hsh[:ord_fob_point] = row[27]
    hsh[:ord_type] = row[28]
    hsh[:ordln_currency] = row[32]
    hsh
  end

  def self.map_detail row
    hsh = {}
    hsh[:ordln_line_number] = row[2].to_i
    hsh[:prod_part_number] = row[5]
    hsh[:prod_vendor_style] = row[6]
    hsh[:prod_name] = row[7]
    hsh[:ordln_color] = row[8]
    hsh[:ordln_color_description] = row[9]
    hsh[:ordln_size] = row[10]
    hsh[:ordln_size_description] = row[11]
    hsh[:ordln_sku] = row[14]
    hsh[:ordln_quantity] = row[17]
    hsh[:ordln_price_per_unit] = row[19]
    hsh[:ordln_wholesale_unit_price] = row[20]
    hsh[:ordln_estimated_unit_landing_cost] = row[21]
    hsh[:ordln_unit_msrp] = row[22]
    hsh
  end

  private

  def process_po rows, opts
    po_number = nil
    begin
      ActiveRecord::Base.transaction do
        header = self.class.map_header rows.first
        po_number = header[:ord_customer_order_number]

        self.class.validate_header(header)
        shipped_lines = []
        ord = update_or_create_order(header, opts) do |saved_ord|
          # First row is the header, so remove it when processing the details
          shipped_lines = process_detail_rows(rows[1..-1], header, saved_ord, opts)
        end
        ord.create_snapshot user, nil, opts[:key]

        if shipped_lines.length > 0
          notify_about_shipped_lines rows, po_number, shipped_lines
        end
      end
    rescue => e
      handle_process_po_error(rows, po_number, e, opts[:key])
    end
  end

  def csv_options
    # setting zero byte as quote character since there's no quoting in the file
    # and the text will include " characters to represent inches
    {col_sep:"|", quote_char: "\x00"}
  end

  def handle_process_po_error rows, po_number, err, file_name
    temp_file_data(rows, po_number) do |f|
      body = "<p>An error occurred attempting to process Ascena PO # #{po_number} from the file #{file_name}.</p>"
      body += "<p>Error:<br>#{ERB::Util.html_escape(err.message)}</p>"
      body += "<p>The CSV lines for this PO were extracted from the Ascena file and are attached.</p>"

      OpenMailer.send_simple_html(["ascena_us@vandegriftinc.com","edisupport@vandegriftinc.com"], "Ascena PO # #{po_number} Errors", body.html_safe, [f]).deliver!
    end
  end

  def temp_file_data rows, po_number
    # convert the rows to a pipe delimited CSV
    Tempfile.open(["Ascena-PO-#{po_number}", ".csv"]) do |f|
      csv = CSV.new(f, csv_options)
      rows.each {|r| csv << r }
      f.flush

      yield f
    end
  end

  def notify_about_shipped_lines rows, po_number, shipped_lines
    temp_file_data(rows, po_number) do |f|
      to = "ascena_us@vandegriftinc.com"
      body = "<p>The following order lines from the Ascena PO # #{po_number} are already shipping and could not be updated:</p>"
      body += "<p><ul>"
      shipped_lines.each do |line|
        body += "<li>Line ##{line[:ordln_line_number]} / Style # #{line[:prod_part_number]} / Shipment # #{Array.wrap(line[:shp_reference]).join(", ")}</li>"
      end
      body += "</ul></p>"
      body += "<p>The CSV lines for this PO were extracted from the Ascena file and are attached.</p>"

      OpenMailer.send_simple_html("ascena_us@vandegriftinc.com", "Ascena PO # #{po_number} Lines Already Shipped", body.html_safe, [f]).deliver!
    end
  end

  def make_product_cache detail_hashes
    part_numbers = detail_hashes.collect {|d| "ASCENA-#{d[:prod_part_number]}"}
    return Product.where(importer_id:importer.id).where("products.unique_identifier IN (?)",part_numbers).includes(:custom_values)
  end

  def process_detail_rows detail_rows, header, ord, opts
    details = detail_rows.map { |dr| self.class.map_detail dr }

    product_cache = make_product_cache(details)

    shipped_line_numbers = Set.new
    unless ord.order_lines.empty?
      # We can't update any lines that have already shipped...so we'll notify of this happening if that occurs.
      lines_to_delete, shipped_lines = separate_shipped_lines(ord.order_lines, details)
      shipped_line_numbers = Set.new(shipped_lines.map {|l| l.line_number })
      lines_to_delete.each(&:destroy)
    end

    shipped_lines = []
    details.each_with_index do |detail, i|
      # Skip any line that does not reference a line that was deleted (.ie the line data references a shipped line)
      if shipped_line_numbers.include?(detail[:ordln_line_number])
        shipped_lines << detail
      else
        self.class.validate_detail(detail, i + 1)
        product = get_or_create_product(detail, header, product_cache,opts[:key])
        create_order_line(ord, detail, header, product)
      end
    end

    shipped_lines
  end

  def separate_shipped_lines order_lines, file_details
    shipped_lines = []
    ok_to_delete = []

    order_lines.each do |line|
      detail = file_details.find {|d| d[:ordln_line_number] == line.line_number }
      if detail
        if line.shipment_lines.empty? 
          ok_to_delete << line
        else
          # add the shipment references to the detail here so we can reference them later in an error message
          detail[:shp_reference] = line.shipment_lines.map {|l| l.shipment.reference }.compact
          shipped_lines << line
        end
      end
    end

    [ok_to_delete, shipped_lines]
  end

  def update_or_create_vendor system_code, name
    # System code can be blank some times, so we won't create a vendor in those cases.
    return nil if system_code.blank?

    vendor = Company.where(system_code:system_code).first_or_create!(name:name)
    vendor.update_attributes!(name: name) unless vendor.name == name
    vendor
  end

  def update_or_create_factory system_code, name, mid
    factory = Company.where(system_code: system_code).first_or_create!(name: name, mid: mid)
    # intentionally not updating MID in case we manually update based on better data from
    # compliance department
    factory.update_attributes!(name: name) unless factory.name == name
    factory
  end

  def update_or_create_order header, opts, &block
    ord = nil
    continue = false
    Lock.acquire("ASCENA-#{header[:ord_customer_order_number]}") do
      ord = Order.where("order_number = ? AND importer_id = #{importer.id}", "ASCENA-#{header[:ord_customer_order_number]}")
                 .includes([:custom_values,:order_lines=>{:product=>:custom_values}])
                 .first_or_initialize(order_number: "ASCENA-#{header[:ord_customer_order_number]}", customer_order_number: header[:ord_customer_order_number],
                                      importer: importer)
      continue = (!ord.persisted? || newer_revision?(ord, header))
      ord.save! if continue
    end
    if continue
      Lock.with_lock_retry(ord) do
        update_order(ord, header, opts, &block) 
      end
    end
    
    ord
  end

  def update_order ord, header, opts
    if newer_revision? ord, header
      vendor = update_or_create_vendor(header[:ord_vend_system_code],header[:ord_vend_name])
      factory = update_or_create_factory(header[:ord_fact_system_code],header[:ord_fact_name],header[:ord_fact_mid]) if header[:ord_fact_system_code].presence

      ord.assign_attributes(order_date: date_parse(header[:ord_order_date]), vendor: vendor, terms_of_sale: header[:ord_terms_of_sale],
                            mode: header[:ord_mode], ship_window_start: date_parse(header[:ord_ship_window_start]),
                            ship_window_end: date_parse(header[:ord_ship_window_end]), fob_point: header[:ord_fob_point],
                            last_file_bucket: opts[:bucket], last_file_path: opts[:key])
      ord.factory = factory if factory
      ord.find_and_set_custom_value(cdefs[:ord_selling_channel], header[:ord_selling_channel])
      ord.find_and_set_custom_value(cdefs[:ord_division], header[:ord_division])
      ord.find_and_set_custom_value(cdefs[:ord_revision], header[:ord_revision])
      ord.find_and_set_custom_value(cdefs[:ord_revision_date], date_parse(header[:ord_revision_date]))
      ord.find_and_set_custom_value(cdefs[:ord_assigned_agent], header[:ord_assigned_agent])
      ord.find_and_set_custom_value(cdefs[:ord_selling_agent], header[:ord_selling_agent])
      ord.find_and_set_custom_value(cdefs[:ord_buyer], header[:ord_buyer])
      ord.find_and_set_custom_value(cdefs[:ord_type], header[:ord_type])
      ord.save!
      yield ord
    end
  end

  def newer_revision? persisted_ord, header
    # Use >= so we allow for reprocessing the latest file
    header[:ord_revision].to_i >= persisted_ord.get_custom_value(cdefs[:ord_revision]).value.to_i
  end

  def get_or_create_product detail, header, product_cache, file_key
    prod_uid = "ASCENA-#{detail[:prod_part_number]}"
    already_existed = false
    product = product_cache.find {|p| p.unique_identifier==prod_uid}
    if product
      already_existed = true
    else
      Lock.acquire(prod_uid) do
        product = Product.where("unique_identifier = ? AND importer_id = ?", prod_uid, importer.id).first_or_initialize
        already_existed = product.persisted?
        product = Product.create!(unique_identifier: prod_uid) unless already_existed
      end
    end

    unless already_existed
      Lock.with_lock_retry(product) do
        product.assign_attributes(name: detail[:prod_name], importer: importer)
        product.find_and_set_custom_value(cdefs[:prod_part_number], detail[:prod_part_number])
        product.find_and_set_custom_value(cdefs[:prod_product_group], header[:prod_product_group])
        product.find_and_set_custom_value(cdefs[:prod_vendor_style], detail[:prod_vendor_style])
        product.save!
      end
      product.create_snapshot user, nil, file_key
      product_cache << product
    end
    product
  end

  def create_order_line order, detail, header, product
    nonags_filter = create_nonags_lambda(header[:ord_type])
    ol = order.order_lines.new(line_number: detail[:ordln_line_number], product: product, sku: detail[:ordln_sku], quantity: detail[:ordln_quantity],
                               price_per_unit: nonags_filter.call(detail[:ordln_price_per_unit], 0), unit_msrp: nonags_filter.call(detail[:ordln_unit_msrp], nil),
                               unit_of_measure: "Each", country_of_origin: header[:ordln_country_of_origin], currency: header[:ordln_currency])
    ol.find_and_set_custom_value(cdefs[:ord_line_department_code], header[:ord_line_department_code])
    ol.find_and_set_custom_value(cdefs[:ord_line_destination_code], header[:ordln_destination_code])
    ol.find_and_set_custom_value(cdefs[:ord_line_season], header[:ordln_season])
    ol.find_and_set_custom_value(cdefs[:ord_line_color], detail[:ordln_color])
    ol.find_and_set_custom_value(cdefs[:ord_line_color_description], detail[:ordln_color_description])
    ol.find_and_set_custom_value(cdefs[:ord_line_size], detail[:ordln_size])
    ol.find_and_set_custom_value(cdefs[:ord_line_size_description], detail[:ordln_size_description])
    ol.find_and_set_custom_value(cdefs[:ord_line_wholesale_unit_price], nonags_filter.call(detail[:ordln_wholesale_unit_price], nil))
    ol.find_and_set_custom_value(cdefs[:ord_line_estimated_unit_landing_cost], nonags_filter.call(detail[:ordln_estimated_unit_landing_cost], nil))
    ol.save!
  end

  def create_nonags_lambda val
    lambda { |input, fail_output| val == "NONAGS" ? fail_output : input }
  end


end; end; end; end
