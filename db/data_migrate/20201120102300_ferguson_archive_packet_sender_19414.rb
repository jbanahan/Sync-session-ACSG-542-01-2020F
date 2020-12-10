class FergusonArchivePacketSender19414 < ActiveRecord::Migration
  def up
    return unless MasterSetup.get.custom_feature?("WWW")

    SchedulableJob.where(run_class: "OpenChain::CustomHandler::Ferguson::FergusonEntryArchivePacketSender",
                         stopped: !MasterSetup.get.production?, run_sunday: true, run_monday: true, run_tuesday: true,
                         run_wednesday: true, run_thursday: true, run_friday: true, run_saturday: true,
                         time_zone_name: "Eastern Time (US & Canada)", run_interval: "12h",
                         no_concurrent_jobs: true).first_or_create!
  end

  def down
    return unless MasterSetup.get.custom_feature?("WWW")

    SchedulableJob.where(run_class: "OpenChain::CustomHandler::Ferguson::FergusonEntryArchivePacketSender").delete_all
  end
end