class TargetCsr18929 < ActiveRecord::Migration
  def up
    return unless MasterSetup.get.custom_feature?("Target")

    job = SchedulableJob.where(run_class: "OpenChain::CustomHandler::Target::TargetCustomsStatusReport").first_or_create!
    if MasterSetup.get.production?
      job.update! run_hour: 7, run_minute: 0, time_zone_name: "Eastern Time (US & Canada)", stopped: true, opts: "{ \"email\":[\"Customs.Expeditor@target.com\", \"dbernardini@vandegriftinc.com\", \"twelsh@vandegriftinc.com\", \"mgrignon@vandegriftinc.com\"] }"
    else
      job.update! stopped: true, opts: "{ \"email\":[\"sbaughman@vandegriftinc.com\"] }"
    end
  end

  def down
    # Does nothing.
  end
end