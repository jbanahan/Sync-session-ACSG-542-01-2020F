require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; class KewillExportShipmentParser
  include OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def self.parse_file data, log, opts = {}
    self.new.parse_file data, log, opts
  end

  def parse_file data, log, opts = {}
    @cdefs ||= self.class.prep_custom_definitions [:prod_part_number]

    # These files are CSV files that use the escape ascii code as a column separator - quote char is bell char
    # simply as a way of "turning off" quoting.
    shipment_headers = ["MFIH01", "MSPH01"]
    shipment_data = []
    CSV.parse(data, col_sep: "\e", quote_char: "\007") do |row|
      # If we've hit a header row, then process anything we've already gathered because this is a 
      # new shipment to record
      if shipment_headers.include? row[0].to_s.upcase
        if shipment_data.length > 0
          # For the moment, the parsing of these files is pretty simplistic so I'm not splitting out
          # the handling of the Ocean File / Ocean Job files into 2 distinct parsers.  If these get
          # any more involved then we should probably do so.
          process_shipment_data(shipment_data, log, opts)
        end

        shipment_data = []
      end

      shipment_data << row
    end

    process_shipment_data(shipment_data, log, opts)

    nil
  end

  def process_shipment_data shipment_data, log, opts
    if shipment_data.length > 0
      if "MFIH01" == shipment_data.first[0].to_s.upcase
        parse_ocean_shipment_file shipment_data, log, opts
      elsif "MSPH01" == shipment_data.first[0].to_s.upcase
        parse_ocean_job_file shipment_data, log, opts
      end
    end
  end

  def parse_ocean_job_file rows, log, opts = {}
    return if (file_number = find_file_number(rows)).blank?

    find_shipment(file_number, find_generated_date(rows), log) do |s|
      rows.each do |row|
        case row[0].to_s.upcase
        when "MSPH01"
          parse_MSPH01 row, s
        when "MSPF01"
          parse_MSPF01 row, s
        end
      end

      save_shipment s, nil
    end
  end

  def parse_MSPH01 row, s
    s.vessel_carrier_scac = row[4]
    s.lading_port = find_port(row[8], false)
    s.unlading_port = find_port(row[9], true)
    s.house_bill_of_lading = row[5]
    # For some reason, ops puts HBL in front of some, but not all House Bill values in the file
    if s.house_bill_of_lading.to_s.starts_with?("HBL")
      s.house_bill_of_lading = s.house_bill_of_lading[4..-1].strip
    end
  end

  def parse_MSPF01 row, s
    s.booking_carrier = row[2]
    s.voyage = row[3]
    s.vessel = row[8]
    s.est_departure_date = parse_date(row[4])
    s.est_arrival_port_date = parse_date(row[6])
  end

  def parse_ocean_shipment_file rows, log, opts = {}
    return if (file_number = find_file_number(rows)).blank?

    find_shipment(file_number, find_generated_date(rows), log) do |s|
      s.shipment_lines.each(&:destroy)
      # I'm not entirely sure why I need reload here, but if I don't I get an error
      # below about trying to update a frozen hash when adding containers to the lines
      s.shipment_lines.reload

      # Just drop a zero in these to ensure there's actually some data to reduce below
      invoice_totals = [BigDecimal(0)]
      freight_lines = [BigDecimal(0)]
      buyer_address = []
      containers = []
      po_number = nil

      rows.each do |row|
        case row[0].to_s.upcase
        when "MFIH01"
          parse_MFIH01 row, s, log
        when "MFIH02"
          parse_MFIH02 row, s
        when "MFIH03"
          parse_MFIH03 row, s
        when "MFIH04"
          parse_MFIH04 row, s
        when "MFIRE1"
          po_number = parse_MFIRE1 row, s
        when "MFIRE2"
          parse_MFIRE2 row, s
        when "MFIIH1"
          invoice_totals << parse_MFIIH1(row, s)
        when "MFIIL1"
          freight_lines << parse_MFIIL1(row, s)
        when "MFIDI1"
          buyer_address << parse_MFIDI1(row, s)
        when "MFICN1"
          containers << parse_MFICN1(row, s)
        when "MFISDT"
          parse_MFISDT(row, s, po_number)
        end
      end

      s.freight_total = freight_lines.compact.reduce(:+)
      s.invoice_total = invoice_totals.compact.reduce(:+)
      s.buyer_address = find_buyer_address(buyer_address, s)
      # If we only have a single container, then associate the container to every shipment line
      if s.containers.length == 1
        container = s.containers.first
        s.shipment_lines.each {|l| l.container = container }
      end

      save_shipment s, containers
    end
  end

  def save_shipment s, containers
    # This method is primarily here because I don't want to add autosave to comments, since that relationship is defined in core_object_support
    # and would carry down to every other core object in the system.
    s.save!
    s.comments.each {|c| c.save! if c.changed? }
    # Autosave for containers is on, so we don't have to deal w/ saving them
    if containers
      # Delete any container record that's not mentioned in the file source file
      s.containers.each {|c| c.destroy unless containers.find {|c2| c2.container_number == c.container_number }}
    end
    s.create_snapshot user
  end

  def parse_MFIH01 row, s, log
    s.importer = find_importer(row[8], log) unless row[8].blank?
    log.company = s.importer
    if "L" == row[5].to_s.strip
      s.mode = "Ocean - LCL"
      s.lcl = true
    else
      s.mode = "Ocean - FCL"
      s.lcl = false
    end
  end

  def parse_MFIH02 row, s
    s.master_bill_of_lading = row[25]
  end

  def parse_MFIH03 row, s
    # Weight in Alliance Export is KGS
    s.gross_weight = BigDecimal(row[2])
  end

  def parse_MFIH04 row, s
    add_unique_comment(s, "Final Destination", row[1].to_s.strip)
    add_unique_comment(s, "Discharge Port", row[3].to_s.strip)
  end

  def parse_MFIRE1 row, s
    row[1].strip
  end

  def parse_MFIRE2 row, s
    s.importer_reference = row[1].strip
  end

  def parse_MFIIH1 row, s
    BigDecimal(row[5])
  end

  def parse_MFIIL1 row, s
    # These are invoice lines...for the moment, only record the Freight amount as a shipment comment
    # The actual invoices are recoverable from Alliance in the bill_history tables.
    amount = nil
    if row[3] == "F"
      amount = BigDecimal(row[7])
    end
    amount
  end

  def parse_MFIDI1 row, s
    row[1]
  end

  def parse_MFICN1 row, s
    container_number = row[1].to_s.strip
    container = s.containers.find {|c| c.container_number == container_number}
    if container.nil?
      container = s.containers.build container_number: container_number
    end

    container.seal_number = row[2]

    container
  end

  def parse_MFISDT row, s, po_number
    commodity = row[10]
    schedule_b = row[1]

    product = find_product s.importer, commodity
    return if product.nil?

    line = s.shipment_lines.build
    line.product = product

    order_line = find_order_line(s.importer, po_number, product, schedule_b)
    line.linked_order_line_id = order_line.id unless order_line.nil?

    line.gross_kgs = BigDecimal(row[9].to_s)
  end

  def find_buyer_address address_lines, s
    # blank the existing buyer address on the shipment and find/create a new one
    s.buyer_address_id = nil
    address = nil

    values = address_lines.find_all {|v| !v.blank? }

    if values.length > 0
      a = Address.new company: s.importer, name: address_lines[0], line_1: address_lines[1], line_2: address_lines[2], line_3: address_lines[3]
      hash_key = Address.make_hash_key a
      existing = Address.where(company_id: a.company.id, address_hash: hash_key).first

      address = (existing.nil?) ? a : existing
    end

    address
  end

  def find_shipment file_number, last_exported_from_source, log
    # Return blank unless the file_number starts with "14".

    # We only want to track Ocean Export for the momemnt and the first 2 digits of the file number is the division (which is 14 for Ocean Export)
    # There ARE both 24 and 34 files for Ocean Export but one represents the billing of the file internally (.ie to our freight division)
    # and the other is some sort of per house bill bill which we don't need to track.

    # Since we don't have a customer available in the ocean job file, I'm going to preface the shipment reference
    # using EXPORT- to avoid collisions with shipments we track for other customers.  The file number is unique
    # for all export shipments, it's analogous to the file number in the entry.
    shipment = nil
    if file_number.starts_with?("14")

      Lock.acquire("ExportShipment") do
        shipment = Shipment.where(reference: "EXPORT-#{file_number}").first_or_create! last_exported_from_source: last_exported_from_source
      end

      if shipment
        Lock.with_lock_retry(shipment) do
          log.company = shipment.importer
          log.add_identifier InboundFileIdentifier::TYPE_SHIPMENT_NUMBER, file_number, module_type:Shipment.to_s, module_id:shipment.id

          # The reason we don't skip files that may be processed out of date has to do with the fact that the data for these files is sent
          # in two files that are generated almost at the same moment, so if we receive them slightly out of order there's a good chance that
          # one of the two files will be skipped...the primarily has to do w/ how our file_pusher does not process files in order of mtime,
          # but also that AWS SQS queues are not guaranteed to process in exact order of receipt time.  As well, the ftp process in Kewill
          # doesn't appear to send in the exact order these export files are generated either.
          shipment.last_exported_from_source = last_exported_from_source
          shipment = yield shipment
        end
      end

    end
    shipment
  end

  def find_importer customer_code, log
    # This is technically the alliance customer, which we pretty much exclusively track as the importer on
    # an import shipment.

    # Because we're slightly shoe-horning export shipments into our clearly import biased shipment screen, I'm going
    # to track the customer as an importer for exports.
    importer = Company.importers.where(alliance_customer_number: customer_code).first
    log.reject_and_raise "No Importer record found with Alliance customer number of #{customer_code}." unless importer
    importer
  end

  def find_file_number rows
    file_number = nil
    first_row = rows.first
    if first_row && first_row.respond_to?(:[])
      file_number = first_row[1]
    end

    file_number
  end

  def user
    @user ||= User.integration
    @user
  end

  def add_unique_comment s, comment_type, value
    comment = s.comments.find {|c| c.subject == comment_type }
    if comment.nil?
      comment = s.comments.build subject: comment_type, user: user
    end

    comment.body = value
    comment
  end

  def find_port port_code, schedule_k = true
    (schedule_k ? Port.where(schedule_k_code: strip_leading_zeros(port_code, 5)) : Port.where(schedule_d_code: strip_leading_zeros(port_code, 4))).first
  end

  def strip_leading_zeros val, length
    val = val.to_s
    while val.length > length && val.starts_with?("0")
      val = val[1..-1]
    end

    val
  end

  def parse_date date
    d = Time.zone.parse(date) rescue nil
    if d
      d = d.to_date
    end

    d
  end

  def parse_file_generated_date date, time
    # Date looks like: 20151106
    # Time looks like: 0000000014550100 (a ton of leading zeros for some reason, and 2 digit milliseconds?)
    ActiveSupport::TimeZone["America/New_York"].parse(date + time[-8..-3]) rescue nil
  end

  def find_generated_date rows
    first_row = rows.first
    parse_file_generated_date(first_row[2], first_row[3])
  end

  def find_product importer, commodity
    return nil if importer.nil? || commodity.blank?

    # Create a product associated w/ the importer w/ the commodity type as the part number (since we don't get actual part numbers in the feed)
    p = Product.where(importer_id: importer.id).where(unique_identifier: "#{importer.alliance_customer_number}-#{commodity}").first_or_initialize
    if p.new_record?
      p.find_and_set_custom_value @cdefs[:prod_part_number], commodity

      p.save!
    end

    p
  end

  def find_order_line importer, po_number, product, hts
    return nil if importer.nil? || po_number.nil?

    order = Order.where(importer_id: importer.id).where(order_number: "#{importer.alliance_customer_number}-#{po_number}").first_or_create! customer_order_number: po_number
    
    # See if this product is on the order, if it's not, add it
    line = order.order_lines.find {|ol| ol.product == product }
    if line.nil?
      line = order.order_lines.create! product: product, hts: hts
    end

    line
  end

end; end; end;