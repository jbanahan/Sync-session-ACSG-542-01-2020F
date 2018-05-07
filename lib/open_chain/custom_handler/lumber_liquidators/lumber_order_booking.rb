module OpenChain; module CustomHandler; module LumberLiquidators; class LumberOrderBooking
  
  def self.can_book? order, user
    return false unless user.edit_shipments?
    return false unless user.company == order.vendor
    return false if order.business_rules_state!='Pass'
    return false unless order.booking_lines_by_order_line.empty?
    return true
  end

  def self.open_bookings_hook user, shipments_query, order
    # We only want to return shipments that are "open" - meaning the received date is nil OR the unlocked date is NOT NULL
    val_def = booking_unlocked_date
    shipments_query.where("`shipments`.booking_received_date IS NULL OR (SELECT v.datetime_value FROM custom_values v WHERE v.customizable_id = `shipments`.id and v.customizable_type = 'Shipment' and v.custom_definition_id = #{val_def.id} LIMIT 1) IS NOT NULL").
      where("`shipments`.canceled_date IS NULL")
  end

  def self.can_request_booking? shipment, user
    perms = base_booking_permissions(shipment, user)
    return false unless perms

    has_booking_request_fields?(shipment) && shipment.booking_received_date.nil?
  end

  def self.has_booking_request_fields? shipment
    return false if shipment.mode.blank? || shipment.shipment_type.blank? || shipment.requested_equipment.blank? || shipment.cargo_ready_date.nil? || shipment.first_port_receipt.nil?

    return false unless shipment.booking_lines.length > 0
    # All booking lines need a Volume on them
    return false unless has_booking_volume?(shipment)

    # We now also need to validate that the delivery location is valid before we can allow booking
    # (Method is split out because it's reference elsewhere as well)
    return false unless valid_delivery_location?(shipment)
    return false unless has_vds_attachment?(shipment)

    true
  end

  def self.valid_delivery_location? shipment
    first_port_of_receipt = shipment.first_port_receipt
    return false unless first_port_of_receipt

    # If the shipment's first port of receipt does not match any booked order's fob point, then 
    # we'll want to add an error notification that indicates as much (screen will take care of displaying this)
     # FOB point should never be blank (it's required for LL vendors to accept the order)
    fob_points = Set.new(Order.where(id: shipment.booking_lines.select(:order_id)).pluck(:fob_point).map {|l| l.to_s.upcase.strip} )
    # If any order's fob point differs from the booking...user shouldn't be able to book
    Set.new([first_port_of_receipt.unlocode.to_s.upcase.strip]) == fob_points
  end

  def self.has_vds_attachment? shipment
    !shipment.attachments.find {|a| a.attachment_type == "VDS-Vendor Document Set"}.nil?
  end

  def self.has_booking_volume? shipment
    !shipment.booking_lines.any? {|l| l.cbms.nil? || l.cbms.zero? }
  end

  def self.can_revise_booking? shipment, user
    perms = base_booking_permissions(shipment, user)
    return false unless perms

    return false unless has_booking_request_fields?(shipment)

    return false if shipment.booking_received_date.nil?

    # Because this is a class level method, we can't really use the custom definition support
    val_def = booking_unlocked_date
    return false unless val_def

    return !shipment.custom_value(val_def).nil?
  end

  def self.can_edit_booking? shipment, user
    perms = base_booking_permissions(shipment, user)
    return false unless perms

    return true if shipment.booking_received_date.nil?

    val_def = booking_unlocked_date
    return false unless val_def
    return !shipment.custom_value(val_def).nil?
  end

  def self.book_from_order_hook ship_hash, order, booking_lines
    if !ship_hash[:id]
      ship_hash[:shp_fwd_syscode] = 'allport'
      ship_hash[:shp_booking_mode] = 'Ocean'
      ship_hash[:shp_booking_shipment_type] = 'CY'

      # Set the ship to id from the order...
      line = order.order_lines.find {|l| !l.ship_to_id.nil? && l.ship_to_id != 0 }
      if line
        ship_hash[:shp_ship_to_address_id] = line.ship_to_id
      end

      # Set the buyer to the importer's ISF buyer address (which will be lumber)
      buyer = order.importer.addresses.where(address_type: "ISF Buyer").first
      if buyer
        ship_hash[:shp_buyer_address_id] = buyer.id
      end

      # Set the consignee to the importer (which will be Lumber)
      ship_hash[:shp_consignee_id] = order.importer.id
    end

    # We need to copy the Gross Weight from the order lines to the booking line hashes.
    # This happens regardless of whether the shipment is new or not.
    booking_lines.each do |line|
      ol = order.order_lines.find {|l| l.id == line[:bkln_order_line_id] }
      gw = order_line_gross_weight
      if ol && gw
        line[:bkln_gross_kgs] = ol.custom_value(gw)
      end

    end

    nil
  end

  def self.request_booking_hook shipment, user
    booking_hook(shipment,user)
  end

  def self.revise_booking_hook shipment, user
    booking_hook(shipment,user)
  end

  def self.base_booking_permissions shipment, user
    return false if shipment.canceled_date
    return false unless shipment.can_edit?(user)
    return false unless shipment.vendor == user.company
    true
  end
  private_class_method :base_booking_permissions

  def self.post_request_cancel_hook shipment, user
    # all cancels are auto-approved since EI doesn't send back a confirmation
    # if things get out of sync with their system, we'll have to resolve manually
    shipment.cancel_shipment! user
  end

  def self.booking_hook shipment, user
    shipment.booking_shipment_type = shipment.shipment_type
    shipment.booking_mode = shipment.mode
    shipment.booking_first_port_receipt_id = shipment.first_port_receipt_id
    shipment.booking_requested_equipment = shipment.requested_equipment
    shipment.booking_cargo_ready_date = shipment.cargo_ready_date

    # Clear the booking unlocked date too
    val_def = booking_unlocked_date
    shipment.find_and_set_custom_value(val_def, nil) if val_def

    nil
  end
  private_class_method :booking_hook


  def self.booking_unlocked_date
    CustomDefinition.where(cdef_uid: "shp_booking_unlocked_date").first
  end

  def self.order_line_gross_weight
    CustomDefinition.where(cdef_uid: "ordln_gross_weight_kg").first
  end

  def self.can_book_order_to_shipment? order, shipment
    return false unless shipment.first_port_receipt.try(:unlocode).to_s.upcase.strip == order.fob_point.to_s.upcase.strip

    # If the shipment already has orders on it, the new order must match the delivery location (fob point)
    # of all the orders on the shipment and also must match the ship to of all the orders.
    order_ids = Set.new
    shipment.booking_lines.each do |line|
      order_ids << line.order_id
    end

    return true if order_ids.size == 0

    orders = Order.where(id: order_ids.to_a).includes(:order_lines).all

    fob_point = order.fob_point.to_s.upcase.strip

    booked_ship_to_ids = Set.new
    orders.each do |booked_order|
      return false if booked_order.fob_point.to_s.upcase.strip != fob_point

      booked_order.order_lines.each do |ol|
        booked_ship_to_ids << ol.ship_to_id
      end
    end

    # Now we need to evaluate that the shipto on the booked orders matches what's on the given order
    order_ship_to_ids = Set.new(order.order_lines.map {|l| l.ship_to_id }.uniq)
    order_ship_to_ids == booked_ship_to_ids
  end

end; end; end; end
