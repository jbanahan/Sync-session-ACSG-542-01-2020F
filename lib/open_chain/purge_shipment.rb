module OpenChain; class PurgeShipment
  def self.run_schedulable
    self.purge
  end

  def self.purge date = 2.years.ago
    # Only get shipments which are not booked. This is similar to booked?
    # Estimated departure date is unreliable, so we check created_at if it's missing
    ids = Shipment.includes([shipment_lines: [piece_sets: [order_line: [:order]]]], :booking_lines)
                  .where(booking_lines: {id: nil})
                  .where('(est_departure_date < ? OR (est_departure_date IS NULL AND shipments.created_at < ?))', date, date)
                  .order('shipments.id ASC')
                  .pluck('shipments.id')

    # Optimization, we're batching 500 ids at a time
    ids.each_slice(500) do |batched_ids|
      shipments = Shipment.where(id: batched_ids)
      next if shipments.empty?

      shipments.each do |shipment|
          shipment.destroy
      rescue StandardError => e
          e.log_me "Failed to purge shipment id #{shipment.id}."
      end

    end
  end
end; end
