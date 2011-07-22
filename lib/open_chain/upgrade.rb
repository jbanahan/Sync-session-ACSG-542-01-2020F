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
      @log_path = "#{Rails.root.to_s}/log/upgrade_#{Time.now}_#{target}.log" 
      @log = Logger.new(@log_path)
      @target = target
    end
    
    #do not call this directly, use the static #upgrade method instead
    def go
      get_source 
      apply_upgrade
      @log_path
    end

    private
    def get_source 
      @log.info "Fetching source"
      capture_and_log 'git fetch'
      @log.info "Fetch complete, checking out #{@target}"
      capture_and_log "git checkout #{@target}"
      @log.info "Source checked out"
    end

    def apply_upgrade log
      
      @log.info "Touching stop.txt"
      capture_and_log "touch tmp/stop.txt"
      @log.info "Stopping Delayed Job"
      DelayedJobManager.stop
      raise UpgradeFailure.new("Delayed job should be stopped and is still running.") if DelayedJobManager.running?
      @log.info "Delayed Job stopped, running bundle install"
      capture_and_log "bundle install"
      @log.info "Bundle complete, running migrations"
      capture_and_log "rake db:migrate"
      @log.info "Migration complete"
      @log.info "Touching restart.txt"
      capture_and_log "touch tmp/restart.txt"
      @log.info "Upgrade complete"
    end

    def capture_and_log command
      stdout, stderr, status = Open3.capture3 command
      @log.info stdout.to_s
      @log.info stderr.to_s
      raise UpgradeFailure.new("#{command} failed: #{stderr}") unless status.success?
    end
  end

  class UpgradeFailure < StandardError

  end
end
