require 'open_chain/service_locator'
module OpenChain; class OrderBookingRegistry
  extend OpenChain::ServiceLocator

  def self.check_validity reg_class
    [:can_book?, :can_request_booking?, :can_revise_booking?, :can_edit_booking?].each do |method|
      raise "OrderBooking Class must implement #{method}" unless reg_class.respond_to?(method)
    end
    prep_stub_methods reg_class
    nil
  end

  def self.prep_stub_methods k
    # stubbing the book from order hook to make it optional
    if !k.respond_to?(:book_from_order_hook)
      def k.book_from_order_hook(ship_hash,order,booking_lines); nil; end
    end
    if !k.respond_to?(:request_booking_hook)
      def k.request_booking_hook(shipment,user); nil; end
    end
    if !k.respond_to?(:revise_booking_hook)
      def k.revise_booking_hook(shipment,user); nil; end
    end
    if !k.respond_to?(:post_request_cancel_hook)
      def k.post_request_cancel_hook(shipment,user); nil; end
    end
    if !k.respond_to?(:open_bookings_hook)
      def k.open_bookings_hook(shipments_query, user, order); shipments_query; end
    end
  end
end; end
