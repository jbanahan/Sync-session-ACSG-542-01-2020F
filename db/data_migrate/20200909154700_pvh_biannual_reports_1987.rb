class PvhBiannualReports1987 < ActiveRecord::Migration
  def up
    return unless MasterSetup.get.custom_feature?("WWW")

    # Standardize the customer number parameter for the existing PVH Duty Assist (aka Data Dump) reports.
    existing_jobs = SchedulableJob.where(run_class: "OpenChain::CustomHandler::Pvh::PvhDutyAssistReport")
                                  .where("opts NOT LIKE '%quarterly%' AND opts NOT LIKE '%biannually%'")
                                  .where("opts LIKE '%cust_number%'")
    existing_jobs.each do |job|
      job.update! opts: job.opts.gsub("cust_number", "company")
    end

    # 4 new scheduled jobs for additional Data Dump variants.
    make_job("PVHCANADA", "quarterly", "Canada Quarterly")
    make_job("PVHCANADA", "biannually", "Canada Biannual")
    make_job("PVH", "quarterly", "US Quarterly")
    make_job("PVH", "biannually", "US Biannual")
  end

  def make_job cust_number, period_label, notes
    email = "[\"GSCGTNSupportServices@pvh.com\",\"armandomendez@pvh.com\",\"myoung@vandegriftinc.com\",\"jillseyfried@pvh.com\",\"matthewrodriguez@pvh.com\",\"davemanzanares@pvh.com\"]"
    SchedulableJob.where(run_class: "OpenChain::CustomHandler::Pvh::PvhDutyAssistReport",
                         opts: "{\"email\":#{email},\"fiscal_day\":1,\"company\":\"#{cust_number}\",\"#{period_label}\":true}",
                         stopped: !MasterSetup.get.production?, run_sunday: true, run_monday: true, run_tuesday: true,
                         run_wednesday: true, run_thursday: true, run_friday: true, run_saturday: true,
                         time_zone_name: "Eastern Time (US & Canada)", run_hour: 2, run_minute: 0,
                         no_concurrent_jobs: false, notes: notes).first_or_create!
  end

  def down
    return unless MasterSetup.get.custom_feature?("WWW")

    # Changes customer number parameter back to the version used by old PvhDutyAssistReport.
    existing_jobs = SchedulableJob.where(run_class: "OpenChain::CustomHandler::Pvh::PvhDutyAssistReport")
                                  .where("opts NOT LIKE '%quarterly%' AND opts NOT LIKE '%biannually%'")
                                  .where("opts LIKE '%company%'")
    existing_jobs.each do |job|
      job.update! opts: job.opts.gsub("company", "cust_number")
    end

    # Newly-added quarterly/biannual jobs: trash 'em.
    SchedulableJob.where(run_class: "OpenChain::CustomHandler::Pvh::PvhDutyAssistReport")
                  .where("opts LIKE '%quarterly%' OR opts LIKE '%biannually%'").delete_all
  end
end