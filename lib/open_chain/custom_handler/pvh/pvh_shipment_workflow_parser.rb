require 'open_chain/xl_client'
require 'open_chain/custom_handler/mass_order_creator'

module OpenChain; module CustomHandler; module Pvh; class PvhShipmentWorkflowParser
  include OpenChain::CustomHandler::MassOrderCreator
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def initialize file
    @custom_file = file
    @cdefs = self.class.prep_custom_definitions [:ord_division, :ord_line_color, :ord_line_destination_code, :prod_part_number, :prod_short_description, :shp_priority]
  end

  def self.can_view? user
    (MasterSetup.get.system_code == "www-vfitrack-net" || Rails.env.development?) && user.company.master?
  end

  def can_view? user
    self.class.can_view? user
  end

  def process user
    errors = []
    results = []
    shipments = 0
    begin
      shipment_result = parse @custom_file
      shipments = shipment_result.length
      shipment_result.each do |result|
        if result[:errors].try(:length).to_i > 0
          errors.push *result[:errors]
        else
          results << result[:shipment]
        end
      end
    rescue
      errors << "Unrecoverable errors were encountered while processing this file.  These errors have been forwarded to the IT department and will be resolved."
      raise
    ensure
      body = "PVH Workflow File '#{@custom_file.attached_file_name}' has finished processing #{shipments} #{"shipment".pluralize(shipments)}. #{results.size} #{"shipment".pluralize(results)} #{results.size > 1 ? "were" : "was"} successfully processed."
      subject = "PVH Workflow Processing Complete"
      if errors.length > 0
        subject += " With Errors"
        body += "<br>The following #{errors.size} #{"error".pluralize(errors.size)} #{errors.size > 1 ? "were" : "was"} received:<br>" + errors.join("<br>")
      end

      user.messages.create(:subject=>subject, :body=>body)
    end
    nil
  end

  def parse custom_file
    # Collect shipments by bol #
    header_found = false
    shipments = Hash.new {|h, k| h[k] = [] }
    xl_client(custom_file).all_row_values do |row|
      if !header_found
        header_found = header_row?(row)
        next
      end

      bol = v(row, 5) + v(row, 6)
      next if bol.blank?

      shipments[bol] << row
    end

    results = []
    shipments.each_pair {|bol, lines| results << process_shipment_lines(User.integration, bol, lines) }
    results
  end

  def process_shipment_lines user, bol, lines
    importer = pvh_importer

    shipment = find_shipment(importer, "PVH-#{bol}")
    orders = build_orders(importer, lines)
    order_objects = create_orders(user, orders.values)

    errors = []
    order_objects.each_pair do |order_no, order|
      errors.push *order.errors.full_messages.map {|m| "Order # #{order_no}: #{m}"}
    end

    if errors.blank?
      shipment = build_shipment shipment, lines, order_objects, user
      {errors: shipment.errors.full_messages, shipment: shipment}
    else
      {errors: errors, shipment: nil}
    end
  end

  def build_orders importer, lines
    # Generate the orders / products for each set of lines, we can then create shipment lines linking to them
    orders = {}
    lines.each do |line|
      # If there's no PO #, there's not much we can do
      order_number = v(line, 14)
      next if order_number.blank?

      order = orders[order_number]
      # Only update order header information if this is the first time the order is encountered
      if order.nil?
        order = {'order_lines_attributes' => []}

        orders[order_number] = order
        order['ord_ord_num'] = "PVH-#{order_number}"
        order['ord_cust_ord_no'] = order_number
        order['ord_imp_id'] = importer.id
        order[uid(:ord_division)] = v(line, 12) + v(line, 13)
      end

      style = "#{pvh_importer.system_code}-#{v(line, 15)}"
      order_line =  order['order_lines_attributes'].find {|line| line['ordln_puid'] == style && line[uid(:ord_line_color)] == v(line, 17)}
      if order_line.nil?
        order_line = {}
        order_line['ordln_puid'] = style
        order_line['ordln_hts'] = v(line, 20)
        order_line['ordln_ppu'] = v(line, 23)
        order_line['ordln_country_of_origin'] = v(line, 9)
        order_line[uid(:ord_line_destination_code)] = v(line, 8)
        order_line[uid(:ord_line_color)] = v(line, 17)

        product = {}
        order_line['product'] = product
        product['prod_uid'] = order_line['ordln_puid']
        product['prod_imp_id'] = importer.id
        product[uid(:prod_part_number)] = v(line, 15)
        # Don't bother saving off any part descriptions...
        # PVH seems to use the same style number for multiple styles (even when the same division is ordering) 
        # and we're really not using the products for anything at this point, except that the order requires them to be
        # there

        order['order_lines_attributes'] << order_line
      end
    end
    orders
  end

  def build_shipment shipment, file_lines, orders, user
    # All shipment header information comes from the first line encountered in the file.
    # We're assuming everythign with the same BOL will share the same shipping information.
    saved = false
    Lock.with_lock_retry(shipment) do
      fl = file_lines.first

      shipment.master_bill_of_lading = v(fl, 5) + v(fl, 6)
      shipment.vessel = v(fl, 3)
      shipment.voyage = v(fl, 32)
      shipment.importer_reference = v(fl, 11)
      shipment.est_arrival_port_date = parse_date(fl, 0)
      shipment.est_departure_date = parse_date(fl, 35)
      shipment.destination_port = parse_port(fl, 31)
      shipment.lading_port = parse_port(fl, 34)
      shipment.find_and_set_custom_value(@cdefs[:shp_priority], v(fl, 7))

      file_lines.each do |line|
        # Find or create the container line this refers to 
        container_number = v(line, 4)
        container = shipment.containers.find {|c| c.container_number == container_number }
        if container.nil?
          container = shipment.containers.build container_number: container_number
        end

        # Find an existing shipment line hooked to the order / style specified on the line
        order = orders["PVH-#{v(line, 14)}"]
        # The uniqueness factor of the order lines in the pvh file is the order / style / color (whish they'd send a sku)
        ol_style = "PVH-#{v(line, 15)}"
        ol_color = v(line, 17)
        # Since we're working with object that may not have been saved, we need to use the actual attribute matches on these rather than the == 
        # equality.  Since id is going to be zero quite a bit (haven't been saved yet)
        order_line = order.order_lines.find {|ol| ol.product.unique_identifier == ol_style && ol.custom_value(@cdefs[:ord_line_color]) == ol_color}
        shipment_line = shipment.shipment_lines.find do |sl| 

          match = sl.container && (sl.container.container_number == container.container_number)
          if match
            match = !sl.order_lines.find {|ol| ol.order.order_number ==  order.order_number && ol.product.unique_identifier == ol_style && ol.custom_value(@cdefs[:ord_line_color]) == ol_color}.nil?
          end
          match
        end

        if shipment_line.nil?
          shipment_line = shipment.shipment_lines.build container: container
          shipment_line.piece_sets.build order_line_id: order_line.id
        end

        # Piece set should never be blank, the shipment_line.order_lines association is done through piece sets above and this is how
        # we locate which line to use (or build a new one, which will have a piece set too)
        piece_set = shipment_line.piece_sets.find {|ps| ps.order_line_id == order_line.id }
        piece_set.quantity = BigDecimal(v(line, 18))
        shipment_line.quantity = BigDecimal(v(line, 18))
        shipment_line.carton_qty = v(line, 25).to_i
        shipment_line.product = order_line.product
      end

      saved = shipment.changed? && shipment.save
    end

    if saved 
      shipment.create_snapshot user
    end

    shipment
  end

  # Override the method from the mass_order_creator to match on style AND color.
  def find_existing_order_line_for_update order, order_line_attributes
    # Name is intentionally long/obscure to prevent accidental override
    order_line = nil
    style = order_line_attributes['ordln_puid']
    color = order_line_attributes[uid(:ord_line_color)]
    # Style can't be blank and if it is, it'll fail a product presence validation later, so just ignore this issue for now.
    if !style.blank?
      order_line = order.order_lines.find {|ol| ol.product.try(:unique_identifier) == style && ol.custom_value(@cdefs[:ord_line_color]).to_s == color}
    end

    order_line
  end


  private

    def xl_client custom_file
      @xl_client ||= OpenChain::XLClient.new(custom_file.path)
    end

    def pvh_importer
      @pvh ||= Company.importers.where(system_code: "PVH").first
      raise "No importer with system code 'PVH' found." unless @pvh
      @pvh
    end

    def find_shipment importer, reference
      shipment = nil
      Lock.acquire("Shipment-#{reference}") do 
        shipment = Shipment.where(importer_id: importer.id, reference: reference).first_or_create!
      end

      shipment
    end

    def v ar, index
      OpenChain::XLClient.string_value(ar[index]).to_s.strip
    end

    def uid id
      @cdefs[id].model_field_uid
    end

    def parse_date ar, index
      val = ar[index]
      if val.respond_to?(:to_date) && !val.is_a?(String)
        val.to_date
      else
        d = val.to_s.strip
        if d.length == 8
          val = Date.strptime d, "%m/%d/%y" rescue nil
        else
          val = Date.strptime d, "%m/%d/%Y" rescue nil
        end
        val
      end
    end

    def parse_port ar, index
      val = v(ar, index)
      Port.where("unlocode = ? OR schedule_k_code = ? OR schedule_d_code = ?", val, val, val).order("unlocode, schedule_k_code, schedule_d_code").first
    end

    def header_row? row
      # If more than 5 of the existing headers are found in the row, consider this the header row
      headers = Set.new ["ETA", "REFERENCE #", "WORKSHEET", "VESSEL", "SHIPMENT", "SCAC", "B/L#", "PRIORITY", "WHSE", "COO", "INVOICE #", "CO", "DIV", "PO", "STYLE", "TH STYLE", "COLOR", "SHIPPED QUANTITY", "STYLE DESCRIPTION", "COST / PC", "CARTONS", "NEED BY DATE", "PORT OF ENTRY", "VOYAGE", "PORT OF DEPARTURE", "ETD"]

      (headers & Set.new(row.map {|r| r.to_s.upcase})).length > 4
    end

end; end; end; end;