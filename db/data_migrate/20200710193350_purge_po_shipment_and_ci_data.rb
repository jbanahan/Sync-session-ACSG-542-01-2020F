class PurgePoShipmentAndCiData < ActiveRecord::Migration
  def up
    SchedulableJob.create!(run_monday: 1, run_hour: 1, stopped: true, run_class: 'OpenChain::PurgeShipment', failure_email: 'bug@vandegriftinc.com', no_concurrent_jobs: 1, notes: 'SOW 1887 purge shipment data older than 2 years from estimated departure date or date created for all clients.')
    SchedulableJob.create!(run_monday: 1, run_hour: 1, stopped: true, run_class: 'OpenChain::PurgeOrder', failure_email: 'bug@vandegriftinc.com', no_concurrent_jobs: 1, notes: 'SOW 1887 purge order data older than 2 years from date created and not linked to any shipments.')
  end

  def down
    SchedulableJob.where(run_class: 'OpenChain::PurgeShipment').destroy_all
    SchedulableJob.where(run_class: 'OpenChain::PurgeOrder').destroy_all
  end
end
