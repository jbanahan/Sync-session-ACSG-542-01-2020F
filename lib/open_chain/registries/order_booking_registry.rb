require 'open_chain/service_locator'
require 'open_chain/registries/registry_support'
module OpenChain; module Registries; class OrderBookingRegistry
  extend OpenChain::ServiceLocator
  extend OpenChain::Registries::RegistrySupport

  def self.check_validity reg_class
    check_registration_validity(reg_class, "OrderBooking", [:can_book?, :can_request_booking?, :can_revise_booking?, :can_edit_booking?])
    nil
  end

  def self.can_book? order, user
    evaluate_registered_permission(:can_book?, order, user)
  end

  def self.can_request_booking? shipment, user
    evaluate_registered_permission(:can_request_booking?, shipment, user)
  end

  def self.can_revise_booking? shipment, user
    evaluate_registered_permission(:can_revise_booking?, shipment, user)
  end

  def self.can_edit_booking? shipment, user
    evaluate_registered_permission(:can_edit_booking?, shipment, user)
  end

  def self.can_book_order_to_shipment? order, shipment
    evaluate_registered_permission(:can_book_order_to_shipment?, order, shipment)
  end

  # Use this method to mutate the ship params utilized to update the shipment when an order is booked.
  # Generally this is where you'd want to set default values.
  def self.book_from_order_hook ship_hash, order, booking_lines
    evaluate_all_registered(:book_from_order_hook, ship_hash, order, booking_lines)
    nil
  end

  # Use this method to set default values on the booking/shipment when a booking is requested.
  def self.request_booking_hook shipment, user
    evaluate_all_registered(:request_booking_hook, shipment, user)
    nil
  end

  # Use this method to set default values on the booking/shipment when a booking is revised
  def self.revise_booking_hook shipment, user
    evaluate_all_registered(:revise_booking_hook, shipment, user)
    nil
  end

  # Use this method to set default values on the booking/shipment when a booking/shipment is requested to be cancelled
  def self.post_request_cancel_hook shipment, user
    evaluate_all_registered(:post_request_cancel_hook, shipment, user)
  end

  # Use this method to add active record query relations to the query built to determine which
  # shipments are open and can be booked to.  Be VERY sure to return the ActiveRecord object you
  # compose from your registry object.
  def self.open_bookings_hook user, shipments_query, order
    registered_objects = registered.select {|r| r.respond_to?(:open_bookings_hook) }

    registered_objects.each {|obj| shipments_query = obj.open_bookings_hook(user, shipments_query, order)}
    shipments_query
  end
  
end; end; end
