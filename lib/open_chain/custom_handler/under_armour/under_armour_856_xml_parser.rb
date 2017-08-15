require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/custom_handler/under_armour/under_armour_business_logic'

module OpenChain; module CustomHandler; module UnderArmour; class UnderArmour856XmlParser
  extend OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include OpenChain::CustomHandler::UnderArmour::UnderArmourBusinessLogic

  class BusinessLogicError < StandardError
  end

  def self.integration_folder
    "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_ua_856_xml"
  end

  def self.parse xml, opts = {}
    self.new.parse xml, opts
  end

  def parse xml_string, opts
    errors = []
    if importer
      process_shipment(REXML::Document.new(xml_string), User.integration, opts[:bucket], opts[:key], errors)
    else
      errors << "Unable to find Under Armour 'UNDAR' importer account."
    end
    send_error_email(xml_string, File.basename(opts[:key]), errors) unless errors.empty?
  end

  def process_shipment xml, user, bucket, file, errors
    ship_xml = xml.root.get_elements("Header").first

    if ship_xml.name != "Header"
      errors << "Invalid XML structure.  Expecting 'Header' element but received '#{ship_xml.name}'"
      return
    end

    # The ExtDocNumber (the ASN # in UA's world) is basically a shipment identifier.
    shipment_number = ship_xml.text "ExtDocNumber"
    revision = ship_xml.text("MessageID").to_i
    s = nil

    find_or_create_shipment(shipment_number, revision, bucket, file) do |shipment|
      parse_shipment_header shipment, ship_xml
      container_number = ship_xml.text "Trailer"
      errors << "#{error_prefix(shipment)} No container number value found in 'Trailer' element." if container_number.blank?

      container = shipment.containers.find {|c| c.container_number == container_number }
      if container.nil?
        container = shipment.containers.build container_number: container_number
      end

      # Clear out all the shipment lines...technically, UA said we wouldn't be getting updates except in cases
      # of big mess ups, but 1) I'm sure there will be a mess up 2) it's very simple to just delete the lines
      # and rebuild.  So lets just handle this scenario.

      # This custom feature check can be removed once all "converted" EEM ASN / Shipment data has been pushed
      # through VFI Track.  Which should be within days of this commit
      shipment.shipment_lines.destroy_all unless MasterSetup.get.custom_feature?("UA EEM Conversion")

      ship_xml.each_element("Order") do |order_xml|
        order_xml.each_element("OrderDetails") do |order_line_xml|
          parse_order_details(shipment, container, order_xml, order_line_xml, errors)
        end
      end

      calculate_shipment_totals shipment

      shipment.save!
      shipment.create_snapshot user, nil, file
      s = shipment
    end

    s
  end

  def send_error_email ship_xml, filename, error
    Tempfile.create(["UA-Shipment-#{Time.zone.now.to_i}", ".xml"]) do |file|
      file << ship_xml
      file.flush
      file.rewind
      Attachment.add_original_filename_method(file, filename) unless filename.blank?

      body = "<p>There was a problem processing the attached Under Armour Shipment XML File. The file that errored is attached.</p><p>Error:"
      body += error.map{|e| ERB::Util.html_escape e}.join("<br>")
      body += "</p>"

      OpenMailer.send_simple_html("edisupport@vandegriftinc.com", "Under Armour Shipment XML Processing Error", body.html_safe, [file]).deliver!
    end
  end

  def calculate_shipment_totals shipment
    shipment.number_of_packages_uom = "CTN"
    shipment.number_of_packages = 0
    shipment.gross_weight = BigDecimal("0")
    shipment.volume = BigDecimal("0")

    shipment.shipment_lines.each do |line|
      shipment.number_of_packages += line.carton_qty unless line.carton_qty.nil?
      shipment.gross_weight += line.gross_kgs unless line.carton_qty.nil?
      shipment.volume += line.cbms unless line.cbms.nil?
    end

    # Round to 2 decimal places, because that's all our database supports (if we don't, then the snapshot may have a ton of 
    # decimal places and then the next snapshot value will show the db truncation and it will look like the next snapshot made a change)
    shipment.gross_weight = shipment.gross_weight.round(2) if shipment.gross_weight.nonzero?
    shipment.volume = shipment.volume.round(2) if shipment.volume.nonzero?
  end

  def parse_shipment_header shipment, ship_xml
    shipment.master_bill_of_lading = ship_xml.text "MasterBOL"
    shipment.house_bill_of_lading = ship_xml.text "SubBOL"
    shipment.vessel_carrier_scac = ship_xml.text "Carrier"
    shipment.est_delivery_date = parse_date(ship_xml, "DeliveryDate")
    # UA refers to this value as the ASN #
    shipment.importer_reference = ship_xml.text "ExtDocNumber"
    # The DocNumber (IBD# in UA's world) will eventually be pulled onto 315's for UA so we need to record it in the shipment
    # Booking Number is a good enough spot for it (even if it's not actually a booking #)
    shipment.booking_number = ship_xml.text "DocNumber"

    shipment
  end

  def error_prefix shipment
    "IBD # #{shipment.booking_number} / ASN # #{shipment.importer_reference}:"
  end

  def parse_order_details shipment, container, order_xml, order_line_xml, errors
    order_number = order_line_xml.text "SAPPurchOrderNum"
    order = find_order(order_number)
    if order.nil?
      errors << "#{error_prefix(shipment)} Failed to find Order # #{order_number}."
      return
    end

    sku = order_line_xml.text "SKU"

    # Find the order line based on the sku...this works for both prepack and standard lines
    order_line = order.order_lines.find {|l| l.sku == sku}

    if order_line.nil?
      errors << "#{error_prefix(shipment)} Failed to find SKU #{sku} on Order #{order_number}."
      return
    end

    shipment_line = shipment.shipment_lines.build
    shipment_line.container = container
    shipment_line.variant = order_line.variant
    shipment_line.product = order_line.product
    shipment_line.quantity = BigDecimal(order_line_xml.text "Qty/Quantity")
    shipment_line.find_and_set_custom_value(cdefs[:shpln_coo], order_line_xml.text("CountryOfOrigin"))

    shipment_line.gross_kgs = BigDecimal("0")
    shipment_line.cbms = BigDecimal("0")
    shipment_line.carton_qty = 0

    vendor_order_number = order_xml.text "Order"
    vendor_order_line_number = order_line_xml.text "LineNum"

    order_xml.elements.each("Carton") do |carton|
      next unless carton.text("CartonDetails/Order") == vendor_order_number && carton.text("CartonDetails/OrderLine") == vendor_order_line_number

      shipment_line.gross_kgs += uom_weight_conversion(BigDecimal(carton.text("Weights/Value[@type = 'GrossWeight']").to_s), carton.text("Weights[Value[@type = 'GrossWeight']]/UOM").to_s)
      length = uom_distance_conversion(BigDecimal(carton.text("Dimensions/Value[@type = 'Length']").to_s), carton.text("Dimensions[Value/@type = 'Length']/UOM"))
      width = uom_distance_conversion(BigDecimal(carton.text("Dimensions/Value[@type = 'Width']").to_s), carton.text("Dimensions[Value/@type = 'Width']/UOM"))
      height = uom_distance_conversion(BigDecimal(carton.text("Dimensions/Value[@type = 'Height']").to_s), carton.text("Dimensions[Value/@type = 'Height']/UOM"))

      shipment_line.cbms += (length * width * height)
      shipment_line.carton_qty += 1
    end

    # Round to 2 decimal places, because that's all our database supports (if we don't, then the snapshot may have a ton of 
    # decimal places and then the next snapshot value will show the db truncation and it will look like the next snapshot made a change)
    shipment_line.cbms = shipment_line.cbms.round(2) if shipment_line.cbms.nonzero?
    shipment_line.gross_kgs = shipment_line.gross_kgs.round(2) if shipment_line.gross_kgs.nonzero?

    shipment_line.piece_sets.build order_line: order_line, quantity: shipment_line.quantity

    shipment_line
  end

  def uom_distance_conversion value, uom
    # Convert to meters
    case uom.to_s.upcase
    when "MT", "M", "CBM"
      value
    when "MM", "MMT"
      value / BigDecimal("1000")
    when "CM", "CMT"
      value / BigDecimal("100")
    when "FT"
      value / BigDecimal("0.3048")
    when "IN"
      value / BigDecimal("0.0254")
    else
      value
    end
  end

  def uom_weight_conversion value, uom
    # Convert to KGs
    case uom.to_s.upcase
    when "KG", "KGM", "KGS"
      value
    when "LB", "LBS"
      value * BigDecimal("0.453592")
    else
      value
    end
  end

  def find_or_create_shipment shipment_number, revision, bucket, file
    shipment_reference = "UNDAR-#{shipment_number}"
    shipment = nil
    Lock.acquire("Shipment-#{shipment_reference}") do
      s = Shipment.where(reference: shipment_reference, importer_id: importer.id).first_or_create!(last_file_bucket: bucket, last_file_path: file)

      if process_file?(revision, s)
        shipment = s
      end
    end

    if shipment
      Lock.with_lock_retry(shipment) do
        shipment.find_and_set_custom_value(cdefs[:shp_revision], revision)
        shipment.last_exported_from_source = Time.zone.now
        shipment.last_file_bucket = bucket
        shipment.last_file_path = file

        yield shipment
      end
    end

    shipment
  end

  def parse_date parent_element, qualifier
    date_string = parent_element.text("DateTime/Date[@DateQualifier = '#{qualifier}']")

    Date.strptime(date_string, "%Y%m%d") rescue nil
  end

  def process_file? revision, shipment
    revision >= shipment.custom_value(cdefs[:shp_revision]).to_i
  end

  def importer 
    @importer ||= Company.importers.where(system_code: "UNDAR").first
    @importer
  end

  def find_order order_number
    @orders ||= Hash.new do |h, k|
      h[k] = Order.where(customer_order_number: k, importer_id: importer.id).first
    end

    @orders[order_number]
  end

  def cdefs
    @cd ||= self.class.prep_custom_definitions([:shp_revision, :shpln_coo])
  end

end; end; end; end