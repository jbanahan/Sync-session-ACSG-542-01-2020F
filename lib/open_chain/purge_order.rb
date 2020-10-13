module OpenChain; class PurgeOrder
  def self.run_schedulable
    self.purge
  end

  def self.purge date = 2.years.ago
    # Only get orders which are not booked. This is similar to booked?
    # Orders which can be removed are not booked and not connected to any shipment lines. We don't want to
    #  remove orders still connected to shipment lines because it be confusing from the UI
    ids = Order.includes([order_lines: [piece_sets: [:shipment_line]]], :booking_lines)
               .where(booking_lines: {id: nil})
               .where(shipment_lines: {id: nil})
               .where('orders.created_at < ?', date)
               .order('orders.id ASC')
               .pluck('orders.id')

    # Optimization, we're batching 500 ids at a time
    ids.each_slice(500) do |batched_ids|
      orders = Order.where(id: batched_ids)
      next if orders.empty?

      orders.each do |order|
          order.destroy
      rescue StandardError => e
          e.log_me "Failed to purge order id #{order.id}."
      end

    end
  end
end; end
