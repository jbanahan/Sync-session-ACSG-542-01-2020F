module OpenChain; module CustomHandler; module LumberLiquidators; class LumberOrderBooking
  def self.can_book? order, user
    return false unless user.edit_shipments?
    return false unless user.company == order.vendor
    return false if order.business_rules_state!='Pass'
    return false unless order.booking_lines_by_order_line.empty?
    return true
  end

  def self.book_from_order_hook ship_hash, order, booking_lines
    if !ship_hash[:id]
      ship_hash[:shp_fwd_syscode] = 'dhl'
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

  def self.can_revise_booking_hook shipment, user
    return false if shipment.canceled_date
    return false unless shipment.can_edit?(user)
    return false unless shipment.vendor == user.company
    return true
  end

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
  end
  private_class_method :booking_hook
end; end; end; end
