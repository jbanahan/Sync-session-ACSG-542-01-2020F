class AddNewsFeedDelayedJobSetup < ActiveRecord::Migration
  def up
    if MasterSetup.get.custom_feature?("WWW")
      SchedulableJob.create!(run_monday: 1, run_tuesday: 1, run_wednesday: 1, run_thursday: 1, run_friday: 1,
        run_saturday: 1, run_sunday: 1,run_interval: "1h", run_class: 'OpenChain::GetNewsFeed', failure_email: 'bug@vandegriftinc.com',
        no_concurrent_jobs: 1, notes: 'Get the Vandegrift Blog news json data and store it in the s3 bucket where it can be attained by the front end without CORS issues.')
    end
  end

  def down
    if MasterSetup.get.custom_feature?("WWW")
      SchedulableJob.where(run_class: 'OpenChain::GetNewsFeed').destroy_all
    end
  end
end
