class PurgeEntryAndStatmentData < ActiveRecord::Migration
  def up
    SchedulableJob.where(run_monday: 1, run_hour: 1, stopped: true, run_class: 'OpenChain::PurgeEntry', failure_email: 'bug@vandegriftinc.com', no_concurrent_jobs: 1, notes: 'SOW 1886 purge entry data older than 8 years for all clients and 5 years for those who do not participate in duty drawback.').first_or_create!
    SchedulableJob.where(run_monday: 1, run_hour: 1, stopped: true, run_class: 'OpenChain::PurgeStatement', failure_email: 'bug@vandegriftinc.com', no_concurrent_jobs: 1, notes: 'SOW 1886 purge statement data older than 5 years for all clients.').first_or_create!
    Company.where(alliance_customer_number: ["CROCS","HENNE","UNDAR","SATCO","TOMS","JCREW","CFLWEST",
      "PUMA","CGOLF","GENES","DASDI","LUMBER","SHOES","TAOS","LANDS","PVH","EDDIE","VOLCOM"]).update_all(drawback_customer: true)
  end

  def down
    SchedulableJob.where(run_class: 'OpenChain::PurgeStatement').destroy_all
    SchedulableJob.where(run_class: 'OpenChain::PurgeEntry').destroy_all
    Company.where(alliance_customer_number: ["CROCS","HENNE","UNDAR","SATCO","TOMS","JCREW","CFLWEST",
      "PUMA","CGOLF","GENES","DASDI","LUMBER","SHOES","TAOS","LANDS","PVH","EDDIE","VOLCOM"]).update_all(drawback_customer: false)
  end
end
