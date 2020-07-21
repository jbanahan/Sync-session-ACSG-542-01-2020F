class BurlingtonBillingJob1933 < ActiveRecord::Migration
  def up
    return unless MasterSetup.get.custom_feature?("WWW")

    job = SchedulableJob.where(run_class: "OpenChain::CustomHandler::Burlington::BurlingtonBillingReport").first_or_create!
    if MasterSetup.get.production?
      job.update! run_sunday: true, run_hour: 7, run_minute: 0, time_zone_name: "Eastern Time (US & Canada)", stopped: false, opts: "{ \"email\":[\"acornwell@vandegriftinc.com\", \"myoung@vandegriftinc.com\"] }"
    else
     job.update! stopped: true, opts: "{ \"email\":[\"myoung@vandegriftinc.com\"] }"
    end
  end

  def down
    # Does nothing.
  end
end