module OpenChain
  class TestInstanceManager
    # call this method to prep the test instance 
    # NEVER CALL THIS IN PRODUCTION, IT CLEARS SCHEDULES AND EDITS USERS
    def self.prep_test_instance new_request_host 
      m = self.new
      m.update_master_setup! new_request_host
      m.clear_schedulable_jobs!
      m.clear_scheduled_reports!
      m.update_users!
    end

    def clear_schedulable_jobs!
      SchedulableJob.scoped.destroy_all
    end

    def clear_scheduled_reports!
      SearchSchedule.scoped.destroy_all 
    end

    def update_master_setup! req_host
      uuid = UUIDTools::UUID.timestamp_create.to_s
      ms = MasterSetup.get
      ms.system_code = req_host.split(".")[0] # system code should equal the machine name of the system (.ie www from www.vfitrack.net)
      ms.uuid = UUIDTools::UUID.timestamp_create.to_s
      ms.request_host = req_host
      ms.ftp_polling_active = false
      ms.custom_features = ''
      ms.stats_api_key = ""
      ms.save!
    end

    def update_users!
      User.scoped.update_all(tariff_subscribed:false)  
    end
  end
end
