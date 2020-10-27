class AddSchedulableJobCalendarDateCheck1749 < ActiveRecord::Migration
  def up
    if MasterSetup.get.custom_feature?("WWW")
      SchedulableJob.create!(day_of_month: 1, run_class: 'OpenChain::CustomHandler::CalendarManager::CalendarRequester', failure_email: 'bug@vandegriftinc.com',
        opts: '{"emails": ["jdavis@vandegriftinc.com", "jbanahan@vandegriftinc.com", "sbaughman@vandegriftinc.com", "wb@vandegriftinc.com",
          "bbommarito@vandegriftinc.com", "jhulford@vandegriftinc.com"],
          "calendars": ["USHol", "CAHol", "PMS","K84Due"]}', no_concurrent_jobs: 1,
          notes: 'Check that there are dates available in the future more than one mouth out. 1749')
    end
  end

  def down
    if MasterSetup.get.custom_feature?("WWW")
      SchedulableJob.where(run_class: 'OpenChain::CustomHandler::CalendarManager::CalendarRequester').destroy_all
    end
  end
end
