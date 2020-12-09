require 'open_chain/purge_options_support'

module OpenChain; class PurgeShipment
  include OpenChain::PurgeOptionsSupport

  def self.run_schedulable opts = {}
    # Definined in PurgeOptionsSupport
    execute_purge(opts, default_years_ago: 3)
  end

  def self.purge older_than:
    # Remove all shipments that are older than the given date
    # Estimated departure date is unreliable, so we check created_at if it's missing
    ids = Shipment.where('(est_departure_date < ? OR (est_departure_date IS NULL AND shipments.created_at < ?))', older_than, older_than)
                  .order('shipments.id ASC')
                  .pluck('shipments.id')

    # Optimization, we're batching 500 ids at a time
    ids.each_slice(500) do |batched_ids|
      shipments = Shipment.where(id: batched_ids)

      shipments.each do |shipment|
        shipment.destroy
      rescue StandardError => e
        e.log_me "Failed to purge shipment id #{shipment.id}."
      end
    end
  end

end; end
