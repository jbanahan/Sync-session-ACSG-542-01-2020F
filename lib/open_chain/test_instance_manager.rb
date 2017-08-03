module OpenChain
  class TestInstanceManager
    # call this method to prep the test instance
    # NEVER CALL THIS IN PRODUCTION, IT CLEARS SCHEDULES AND EDITS USERS
    def self.prep_test_instance new_request_host, uuid
      m = self.new
      m.update_master_setup! new_request_host, uuid
      m.clear_schedulable_jobs!
      m.clear_scheduled_reports!
      m.update_users! new_request_host
    end

    def clear_schedulable_jobs!
      SchedulableJob.scoped.destroy_all
    end

    def clear_scheduled_reports!
      SearchSchedule.scoped.destroy_all
    end

    def update_master_setup! req_host, uuid
      # Load the master setup from the database (NOT from memcache)
      # This is because other test instances may be running against a previous database version -
      # since this is pretty much the first step to run when deploying a new test database.
      ms = MasterSetup.first
      ms.system_code = req_host.split(".")[0] # system code should equal the machine name of the system (.ie www from www.vfitrack.net)
      if uuid.blank?
        # Use the request host name as the basis for the UUID.  This way we can just keep using the same uuid for progressive iterations
        # of the same test system and not end up creating different S3 buckets for everything.
        ms.uuid = UUIDTools::UUID.md5_create(UUIDTools::UUID_DNS_NAMESPACE, req_host).to_s
      else
        ms.uuid = uuid
      end
      
      ms.request_host = req_host
      ms.ftp_polling_active = false
      ms.custom_features = ''
      ms.stats_api_key = ""
      ms.save!
    end

    def update_users! request_host
      User.scoped.update_all(tariff_subscribed:false, host_with_port: request_host)
      EventSubscription.delete_all
    end
  end
end
