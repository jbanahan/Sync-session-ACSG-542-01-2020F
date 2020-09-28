class LumberFenixProdFeature1992 < ActiveRecord::Migration
  def up
    ms = MasterSetup.get
    return unless ms.custom_feature?("Lumber Liquidators")

    if !ms.custom_feature?("Full Fenix Product File")
      ms.custom_features_list = (ms.custom_features_list << "Full Fenix Product File")
      ms.save!
    end

    lumber = Company.where(system_code: "LUMBER").first
    if lumber
      fenix_job = SchedulableJob.where(run_class: "OpenChain::CustomHandler::FenixProductFileGenerator").first
      if !fenix_job
        fenix_job = SchedulableJob.where(run_class: "OpenChain::CustomHandler::LumberLiquidators::LumberFenixProductFileGenerator").first_or_create!
      end
      fenix_job.update! run_class: "OpenChain::CustomHandler::LumberLiquidators::LumberFenixProductFileGenerator",
                        opts: "{\"fenix_customer_code\":\"LUMBER\",\"importer_id\":#{lumber.id}, \"strip_leading_zeros\": true}",
                        stopped: !MasterSetup.get.production?, run_sunday: true, run_monday: true, run_tuesday: true,
                        run_wednesday: true, run_thursday: true, run_friday: true, run_saturday: true,
                        time_zone_name: "Eastern Time (US & Canada)", run_interval: "60m", no_concurrent_jobs: true
    end
  end

  def down
    ms = MasterSetup.get
    return unless ms.custom_feature?("Lumber Liquidators")

    if ms.custom_feature?("Full Fenix Product File")
      feat_list = ms.custom_features_list
      feat_list.delete("Full Fenix Product File")
      ms.custom_features_list = feat_list
      ms.save!
    end

    fenix_job = SchedulableJob.where(run_class: "OpenChain::CustomHandler::LumberLiquidators::LumberFenixProductFileGenerator").first
    lumber = Company.where(system_code: "LUMBER").first
    if fenix_job && lumber
      fenix_job.update! run_class: "OpenChain::CustomHandler::FenixProductFileGenerator",
                        opts: "{\"fenix_customer_code\":\"LUMBER\",\"importer_id\":#{lumber.id}, \"strip_leading_zeros\": true, \"suppress_country\": true}"
    end
  end
end