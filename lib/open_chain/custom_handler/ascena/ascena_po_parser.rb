require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; module Ascena; class AscenaPoParser
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include OpenChain::IntegrationClientParser

  def self.integration_folder
    ["www-vfitrack-net/_ascena_po", "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_ascena_po"]
  end

  def self.parse pipe_delimited_content, opts={}
    self.new.process_file(pipe_delimited_content, opts)
  end

  def process_file pipe_delimited_content, opts={}
    po_rows = []
    user = User.integration
    begin
      # setting zero byte as quote character since there's no quoting in the file
      # and the text will include " characters to represent inches
      CSV.parse(pipe_delimited_content, {col_sep:"|", quote_char: "\x00"}) do |row|
        next if blank_row?(row)
        if(row[0] == 'H')
          if po_rows.length > 0
            # The reason we're delaying here is so that we can let any transient db/locking/etc type of errors
            # bubble up and transparently let delayed jobs reprocess the file chunk
            self.delay.process_po(user, po_rows, opts[:bucket], opts[:key])
            po_rows = []
          end
        end
        po_rows << row
      end
      self.delay.process_po(user, po_rows, opts[:bucket], opts[:key]) if po_rows.length > 0
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

  class BusinessLogicError < StandardError

  end

  def validate_header header
    raise BusinessLogicError, "Customer order number missing" if header[:ord_customer_order_number].blank?
  end

  def validate_detail detail, row_num
    raise BusinessLogicError, "Part number missing on row #{row_num}" if detail[:prod_part_number].blank?
    raise BusinessLogicError, "Quantity missing on row #{row_num}" if detail[:ordln_quantity].blank?
    raise BusinessLogicError, "Line number missing on row #{row_num}" if detail[:ordln_line_number].nil? || detail[:ordln_line_number].zero?
  end


  def map_header row
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

  def map_detail row
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


  def process_po user, rows, bucket, filename
    po_number = nil
    begin
      header = map_header rows.first
      po_number = header[:ord_customer_order_number]

      validate_header(header)
      detail_rows = []
      # First row is the header, so remove it when processing the details
      rows[1..-1].each_with_index do |dr, x| 
        row = map_detail dr
        validate_detail row, x + 1
        detail_rows << row
      end
      product_cache = make_product_cache(user, header, detail_rows, filename)

      shipped_lines = []
      ord = update_or_create_order(header, bucket, filename) do |saved_ord|
        
        shipped_lines = process_detail_rows(detail_rows, header, saved_ord, product_cache)
      end
      ord.create_snapshot user, nil, filename

      if shipped_lines.length > 0
        notify_about_shipped_lines rows, po_number, shipped_lines
      end
    rescue BusinessLogicError => e
      handle_process_po_error(rows, po_number, e, filename)
    end
  end

  private

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
      csv = CSV.new(f, {col_sep:"|"})
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

  def make_product_cache user, header, detail_hashes, file_name
    cache = {}
    detail_hashes.each do |detail_row|
      product = get_or_create_product(user, header, detail_row, file_name)
      cache[product.unique_identifier] = product
    end
    
    cache
  end

  def process_detail_rows detail_rows, header, ord, product_cache

    shipped_line_numbers = Set.new
    unless ord.order_lines.empty?
      # We can't update any lines that have already shipped...so we'll notify of this happening if that occurs.
      lines_to_delete, shipped_lines = separate_shipped_lines(ord.order_lines, detail_rows)
      shipped_line_numbers = Set.new(shipped_lines.map {|l| l.line_number })
      lines_to_delete.each(&:destroy)
    end

    shipped_lines = []
    detail_rows.each_with_index do |detail, i|
      # Skip any line that does not reference a line that was deleted (.ie the line data references a shipped line)
      if shipped_line_numbers.include?(detail[:ordln_line_number])
        shipped_lines << detail
      else
        product = product_cache["ASCENA-#{detail[:prod_part_number]}"]
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

    identifier = SystemIdentifier.where(system: "Ascena PO", code: system_code).first_or_create!
    vendor = identifier&.company
    if vendor.nil?
      # We actually still need the system code for now, since several reports rely on it being in the company
      # rather than an identifier
      vendor = Company.create! name: name, vendor: true, system_code: system_code
      identifier.update_attributes! company_id: vendor.id
      importer.linked_companies << vendor
    end
    
    vendor.update_attributes!(name: name) unless vendor.name == name
    vendor
  end

  def update_or_create_factory system_code, name, mid
    identifier = SystemIdentifier.where(system: "Ascena PO", code: system_code).first_or_create!
    factory = identifier&.company

    if factory
      attributes = {}
      attributes[:name] = name if !name.blank? && name != factory.name
      attributes[:mid] = mid if !mid.blank? && mid != factory.mid

      factory.update_attributes!(attributes) if attributes.size > 0
    elsif !name.blank?
      factory = Company.create! system_code: system_code, name: name, mid: mid, factory: true
      identifier.update_attributes! company_id: factory.id
      importer.linked_companies << factory
    end
    
    factory
  end

  def update_or_create_order header, bucket, filename, &block
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
        update_order(ord, header, bucket, filename, &block) 
      end
    end

    ord
  end

  def update_order ord, header, bucket, filename
    if newer_revision? ord, header
      vendor = update_or_create_vendor(header[:ord_vend_system_code],header[:ord_vend_name])
      factory = update_or_create_factory(header[:ord_fact_system_code],header[:ord_fact_name],header[:ord_fact_mid]) if header[:ord_fact_system_code].presence

      ord.assign_attributes(order_date: date_parse(header[:ord_order_date]), vendor: vendor, terms_of_sale: header[:ord_terms_of_sale],
                            mode: header[:ord_mode], ship_window_start: date_parse(header[:ord_ship_window_start]),
                            ship_window_end: date_parse(header[:ord_ship_window_end]), fob_point: header[:ord_fob_point],
                            last_file_bucket: bucket, last_file_path: filename)
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

  def get_or_create_product user, header, detail, file_key
    product = nil
    prod_uid = "ASCENA-#{detail[:prod_part_number]}"
    Lock.acquire(prod_uid) do
      p = Product.where("unique_identifier = ? AND importer_id = ?", prod_uid, importer.id).first_or_initialize
      return p if p.persisted?

      product = Product.create!(unique_identifier: prod_uid, importer_id: importer.id)
    end

    Lock.with_lock_retry(product) do
      product.assign_attributes(name: detail[:prod_name], importer: importer)
      product.find_and_set_custom_value(cdefs[:prod_part_number], detail[:prod_part_number])
      product.find_and_set_custom_value(cdefs[:prod_product_group], header[:prod_product_group])
      product.find_and_set_custom_value(cdefs[:prod_vendor_style], detail[:prod_vendor_style])
      product.save!
    end
    product.create_snapshot user, nil, file_key

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

  def importer
    @importer ||= Company.where(system_code: "ASCENA", importer: true).first
    raise "No Importer company found with system code 'ASCENA'." unless @importer
    @importer
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions [:ord_line_season, :ord_buyer,:ord_division,:ord_revision, :ord_revision_date, 
      :ord_assigned_agent, :ord_selling_agent, :ord_selling_channel, :ord_type, :ord_line_color, :ord_line_color_description,
      :ord_line_department_code,:ord_line_destination_code, :ord_line_size_description,:ord_line_size,
      :ord_line_wholesale_unit_price, :ord_line_estimated_unit_landing_cost,:prod_part_number,
      :prod_product_group,:prod_vendor_style ]
  end


end; end; end; end
