require 'open3'

module OpenChain
  class Upgrade

    #Upgrades the current instance to the target git tag
    #returns the absolute path to the upgrade log file
    #raises an OpenChain::UpgradeFailure if there are any problems
    def self.upgrade target
      Upgrade.new(target).go
    end

    # Check the MasterSetup to see if this instance needs to be upgrade to another version and do so if needed
    #raises an OpenChain::UpgradeFailure if there are any problems
    def self.upgrade_if_needed
      if MasterSetup.need_upgrade?
        upgrade MasterSetup.get(false).target_version
      end
    end

    def self.upgrade_delayed_job_if_needed
      if MasterSetup.need_upgrade?
        Upgrade.new(MasterSetup.get(false).target_version).go_delayed_job
      end
    end

    def self.in_progress?
      File.exists?(upgrade_file_path)
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
    def go
      return "Skipping, upgrade_running.txt exists" if Upgrade.in_progress?
      @upgrade_log = InstanceInformation.check_in.upgrade_logs.create(:started_at=>0.seconds.ago, :from_version=>MasterSetup.current_code_version, :to_version=>@target)
      begin
        @log = Logger.new(@log_path)
        capture_and_log "touch #{upgrade_file_path}"
        get_source 
        apply_upgrade
        #upgrade_running.txt will stick around if one of the previous methods blew an exception
        #this is on purpose, so upgrades won't kick off if we're in an indeterminent failed state
        capture_and_log "rm #{upgrade_file_path}" 
        @log_path
      rescue
        @log.error $!.message
        raise $!
      ensure
        finish_upgrade_log 
      end
    end

    def go_delayed_job
      return "Skipping, upgrade_running.txt exists" if Upgrade.in_progress?
      @upgrade_log = InstanceInformation.check_in.upgrade_logs.create(:started_at=>0.seconds.ago, :from_version=>MasterSetup.current_code_version, :to_version=>@target)
      begin
        @log = Logger.new(@log_path)
        capture_and_log "touch #{upgrade_file_path}"
        get_source 
        migrate
        log_me "Migration complete"
        capture_and_log "rm #{upgrade_file_path}" 
        # Remove the upgrade error file if it is present
        capture_and_log("rm #{upgrade_error_file_path}") if File.exists?(upgrade_error_file_path)
        log_me "Upgrade complete"
        @log_path
      rescue
        # If the delayed job upgrade fails at some point we'll need to remove the upgrade_running.txt file in order to get the upgrade
        # to start again, however, if we do that the dj_monitor.sh script may actually restart delayed job queues prior to the environment being ready for that.
        # Therefore, use the presence of another upgrade_error.txt flag file to tell it not to start the queue.
        capture_and_log "touch #{upgrade_error_file_path}"
        @log.error $!.message
        raise $!
      ensure
        finish_upgrade_log 
        DelayedJobManager.restart
      end
    end

    private
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
      log_me "Touching restart.txt"
      capture_and_log "touch tmp/restart.txt"
      log_me "Upgrade complete"
    end
    
    def migrate
      c = 0
      while !MasterSetup.get_migration_lock && c<30 #5 minute wait
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

  end

  class UpgradeFailure < StandardError

  end
end
