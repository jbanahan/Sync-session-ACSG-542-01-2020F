module OpenChain; module Registries; class DefaultOrderBookingRegistry

  def self.can_book? order, user
    user.edit_shipments?
  end

  def self.can_request_booking? shipment, user
    default_can_request_booking? shipment, user
  end

  def self.default_can_request_booking? shipment, user, ignore_shipment_state = false
    unless ignore_shipment_state
      return false if shipment.booking_received_date || shipment.booking_approved_date || shipment.booking_confirmed_date
    end
    return false unless shipment.can_view?(user)
    return false unless shipment.vendor == user.company || user.company.master?
    return true
  end
  private_class_method :default_can_request_booking?

  def self.can_revise_booking? shipment, user
    # Can't revise bookings that have shipment lines
    return false if shipment.shipment_lines.length > 0

    # Can't revise bookings that haven't been confirmed or approved
    return false unless shipment.booking_approved_date || shipment.booking_confirmed_date

    if !shipment.booking_confirmed_date
      # Users that can request or approve bookings can revise if it's not confirmed
      return true if shipment.can_approve_booking?(user, true) || default_can_request_booking?(shipment, user, true)
    else
      # If there's a booking confirm date, only user's that can confirm can revise a booking
      return true if shipment.can_confirm_booking?(user, true)
    end
    return false
  end

  def self.can_edit_booking? shipment, user
    # By default, just use the can_edit shipment register
    shipment.can_edit?(user)
  end

  def self.can_book_order_to_shipment? order, shipment
    # By default we'll allow any order to be booked to the shipment...note this is called after actual permissions handling is 
    # done to prevent vendors, etc from booking things they can't actually see. This is only adding on extra permissions.
    true
  end

  # Use this method to set default values on the booking/shipment when a booking/shipment is requested to be cancelled
  def self.post_request_cancel_hook shipment, user
    evaluate_all_registered(:post_request_cancel_hook, shipment, user)
  end

  # Use this method to add active record query relations to the query built to determine which
  # shipments are open and can be booked to.  Be VERY sure to return the ActiveRecord object you
  # compose from your registry object.
  def self.open_bookings_hook user, shipments_query, order
    shipments_query.where(shipment_instructions_sent_date: nil)
  end

  def self.book_from_order_hook ship_hash, order, booking_lines
    # If the shipment is being created from the order, only then include the ship from
    if !ship_hash[:id]
      ship_hash[:shp_ship_from_id] = order.ship_from_id
    end
  end

end; end; end;