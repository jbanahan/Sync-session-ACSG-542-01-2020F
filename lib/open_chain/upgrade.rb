require 'open3'

module OpenChain
  class Upgrade

    @@upgraded = false

    # This method is just a flag to denote if and upgrade completed in this process, it's largely useless
    # to anything other than jobs that initiate an upgrade.  It's here to attempt to prevent
    # doing a second upgrade after one has already occurred.
    def self.upgraded?
      @@upgraded
    end

    #Upgrades the current instance to the target git tag, specifying whether the upgrade is running from a delayed job queue or not.
    #returns the absolute path to the upgrade log file
    #raises an OpenChain::UpgradeFailure if there are any problems
    def self.upgrade target, upgrade_delelayed_job = false, callbacks = {}
      Upgrade.new(target).go upgrade_delelayed_job, callbacks
    end

    # Check the MasterSetup to see if this instance needs to be upgrade to another version and do so if needed
    #raises an OpenChain::UpgradeFailure if there are any problems
    def self.upgrade_if_needed callbacks = {}
      result = false
      if MasterSetup.need_upgrade?
        result = upgrade MasterSetup.get(false).target_version, false, callbacks
      end
      result
    end

    # Don't change the argument order ro method name without also consulting 
    # delayed_jobs_intializers.
    def self.upgrade_delayed_job_if_needed
      result = false
      if MasterSetup.need_upgrade?
        result = upgrade MasterSetup.get(false).target_version, true
      end
      result
    end

    def self.in_progress?
      File.exists?(upgrade_file_path)
    end

    def self.errored?
      File.exists?(upgrade_error_file_path)
    end

    def self.upgrade_file_path
      "tmp/upgrade_running.txt"
    end

    def self.upgrade_error_file_path
      "tmp/upgrade_error.txt"
    end

    #do not initialize this method directly, use the static #upgrade method instead
    def initialize target
      @target = target
      @log_path = "#{Rails.root.to_s}/log/upgrade_#{Time.now.to_s.gsub(/[ :]/,"_")}_#{target}.log" 
    end

    #do not call this directly, use the static #upgrade method instead
    def go delayed_job_upgrade, callbacks = {}
      # Make sure only a single process is checking for and creating the upgrade file at a time
      # to avoid multiple upgrades running on the same host/customer instance at a time.
      @log = nil
      @upgrade_log = nil
      unless Upgrade.upgraded?
        Lock.acquire(Lock::UPGRADE_LOCK) do
          unless Upgrade.in_progress?
            @log = Logger.new(@log_path)
            # The log statement for this commeand will get sucked into the upgrade log when it's created
            capture_and_log "touch #{Upgrade.upgrade_file_path}"
          end
        end
      end

      return false unless @log
      
      execute_callback(callbacks, :running)
      upgrade_completed = false
      begin
        @upgrade_log = InstanceInformation.check_in.upgrade_logs.create(:started_at=>0.seconds.ago, :from_version=>MasterSetup.current_code_version, :to_version=>@target, :log=>IO.read(@log_path))
        get_source 
        apply_upgrade
        #upgrade_running.txt will stick around if one of the previous methods blew an exception
        #this is on purpose, so upgrades won't kick off if we're in an indeterminent failed state
        capture_and_log "rm #{Upgrade.upgrade_file_path}" 
        # Remove the upgrade error file if it is present
        capture_and_log("rm #{Upgrade.upgrade_error_file_path}") if delayed_job_upgrade && File.exists?(Upgrade.upgrade_error_file_path)
        @@upgraded = true
        upgrade_completed = true
      rescue
        # If the delayed job upgrade fails at some point we'll need to remove the upgrade_running.txt file in order to get the upgrade
        # to start again, however, if we do that the dj_monitor.sh script may actually restart delayed job queues prior to the environment being ready for that.
        # Therefore, use the presence of another upgrade_error.txt flag file to tell it not to start the queue.
        capture_and_log "touch #{Upgrade.upgrade_error_file_path}" if delayed_job_upgrade
        @log.error $!.message
        raise $!
      ensure
        finish_upgrade_log 
      end

      upgrade_completed
    end

    # private
    def finish_upgrade_log
      @upgrade_log.update_attributes(:finished_at=>0.seconds.ago,:log=>IO.read(@log_path)) if !@upgrade_log.nil? && File.exists?(@log_path)
    end
    def get_source 
      log_me "Fetching source"
      capture_and_log 'git fetch'
      log_me "Fetch complete, checking out #{@target}"
      capture_and_log "git checkout #{@target}"
      log_me "Source checked out"
      log_me "Running bundle install"
      capture_and_log "bundle install --without=development test"
      log_me "Bundle complete, running migrations"
    end

    def apply_upgrade
      log_me "Touching stop.txt"
      capture_and_log "touch tmp/stop.txt"
      migrate
      precompile
      init_schedulable_jobs
      log_me "Touching restart.txt"
      capture_and_log "touch tmp/restart.txt"
      log_me "Upgrade complete"
    end
    
    def init_schedulable_jobs
      load 'app/models/schedulable_job.rb' #get latest code
      SchedulableJob.create_default_jobs!
    end

    def migrate
      c = 0
      #10 minute wait - 5 minute wait proved to be a bit short once or twice when running migrations on data associated with a large table
      while !MasterSetup.get_migration_lock && c<60 
        log_me "Waiting for #{MasterSetup.get.migration_host} to release migration lock"
        sleep 10
        c += 1
      end
      raise UpgradeFailure.new("Migration lock wait timed out.") unless MasterSetup.get_migration_lock
      capture_and_log "rake db:migrate"
      MasterSetup.release_migration_lock
      log_me "Migration complete"
    end

    def capture_and_log command
      stdout, stderr, status = Open3.capture3 command
      log_me stdout unless stdout.blank?
      log_me stderr unless stderr.blank?
      raise UpgradeFailure.new("#{command} failed: #{stderr}") unless status.success?
    end
    def precompile 
      log_me "Precompiling assets"
      capture_and_log "rake assets:precompile"
      log_me "Precompile complete"
    end
    
    def log_me txt
      @log.info txt
      @upgrade_log.update_attributes(:log=>IO.read(@log_path)) if !@upgrade_log.nil? && File.exists?(@log_path)
    end

    def execute_callback callback_list, event
      if callback_list && callback_list[event]
        cb_list = callback_list[event]
        to_run = []
        if cb_list.respond_to? :entries 
          to_run = cb_list.entries 
        else
          to_run << cb_list
        end

        to_run.each do |callback|
          callback.call
        end
      end
    end
  end

  class UpgradeFailure < StandardError

  end
end
