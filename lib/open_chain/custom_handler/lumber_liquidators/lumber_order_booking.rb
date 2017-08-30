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
    shipments_query.where("`shipments`.booking_received_date IS NULL OR (SELECT v.datetime_value FROM custom_values v WHERE v.customizable_id = `shipments`.id and v.customizable_type = 'Shipment' and v.custom_definition_id = #{val_def.id} LIMIT 1) IS NOT NULL")
  end

  def self.can_request_booking? shipment, user
    perms = base_booking_permissions(shipment, user)
    return false unless perms

    has_booking_request_fields?(shipment) && shipment.booking_received_date.nil?
  end

  def self.has_booking_request_fields? shipment
    return false if shipment.mode.blank? || shipment.shipment_type.blank? || shipment.requested_equipment.blank? || shipment.cargo_ready_date.nil? || shipment.first_port_receipt.nil?

    return true
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
    end
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
end; end; end; end
