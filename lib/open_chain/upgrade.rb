require 'open3'

module OpenChain
  class Upgrade

    #Upgrades the current instance to the target git tag
    #returns the absolute path to the upgrade log file
    #raises and OpenChain::UpgradeFailure if there are any problems
    def self.upgrade target
      Upgrade.new(target).go
    end

    #do not initialize this method directly, use the static #upgrade method instead
    def initialize target
      @target = target
      @log_path = "#{Rails.root.to_s}/log/upgrade_#{Time.now.to_s.gsub(/[ :]/,"_")}_#{target}.log" 
    end
    
    #do not call this directly, use the static #upgrade method instead
    def go
      return "Skipping, upgrade_running.txt exists"if File.exists?("tmp/upgrade_running.txt")
      @upgrade_log = InstanceInformation.check_in.upgrade_logs.create(:started_at=>0.seconds.ago, :from_version=>MasterSetup.get.version, :to_version=>@target)
      begin
        @log = Logger.new(@log_path)
        capture_and_log "touch tmp/upgrade_running.txt"
        get_source 
        apply_upgrade
        #upgrade_running.txt will stick around if one of the previous methods blew an exception
        #this is on purpose, so upgrades won't kick off if we're in an indeterminent failed state
        capture_and_log "rm tmp/upgrade_running.txt" 
        @log_path
      rescue
        @log.error $!.message
        raise $!
      ensure
        finish_upgrade_log 
      end
    end

    private
    def finish_upgrade_log
      @upgrade_log.update_attributes(:finished_at=>0.seconds.ago,:log=>IO.read(@log_path)) if !@upgrade_log.nil? && File.exists?(@log_path)
    end
    def get_source 
      @log.info "Fetching source"
      capture_and_log 'git fetch'
      @log.info "Fetch complete, checking out #{@target}"
      capture_and_log "git checkout #{@target}"
      @log.info "Source checked out"
    end

    def apply_upgrade
      
      @log.info "Touching stop.txt"
      capture_and_log "touch tmp/stop.txt"
      @log.info "Stopping Delayed Job"
      DelayedJobManager.stop
      dj_count = 0
      while DelayedJobManager.running? && dj_count < 10
        @log.info "Waiting for delayed job to stop"
        sleep 10
        dj_count += 1
      end
      raise UpgradeFailure.new("Delayed job should be stopped and is still running.") if DelayedJobManager.running?
      @log.info "Delayed Job stopped, running bundle install"
      capture_and_log "bundle install"
      @log.info "Bundle complete, running migrations"
      migrate
      @log.info "Migration complete"
      @log.info "Touching restart.txt"
      capture_and_log "touch tmp/restart.txt"
      @log.info "Upgrade complete"
    end
    
    def migrate
      c = 0
      while !MasterSetup.get_migration_lock && c<12 #2 minute wait
        @log.info "Waiting for #{MasterSetup.get.migration_host} to release migration lock"
        sleep 10
        c += 1
      end
      raise UpgradeFailure.new("Migration lock wait timed out.") unless MasterSetup.get_migration_lock
      capture_and_log "rake db:migrate"
    end

    def capture_and_log command
      stdout, stderr, status = Open3.capture3 command
      @log.info stdout unless stdout.blank?
      @log.info stderr unless stderr.blank?
      raise UpgradeFailure.new("#{command} failed: #{stderr}") unless status.success?
    end
  end

  class UpgradeFailure < StandardError

  end
end
