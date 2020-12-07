require 'open3'
require 'fileutils'
require 'open_chain/slack_client'
require 'open_chain/load_environment'

module OpenChain
  class Upgrade

    @@upgraded = false

    # This method is just a flag to denote if and upgrade completed in this process, it's largely useless
    # to anything other than jobs that initiate an upgrade.  It's here to attempt to prevent
    # doing a second upgrade after one has already occurred.
    def self.upgraded?
      @@upgraded
    end

    # Upgrades the current instance to the target git tag, specifying whether the upgrade is running from a delayed job queue or not.
    # returns the absolute path to the upgrade log file
    # raises an OpenChain::UpgradeFailure if there are any problems
    def self.upgrade target, upgrade_delelayed_job = false, callbacks = {}
      Upgrade.new(target).go upgrade_delelayed_job, callbacks
    end

    # Check the MasterSetup to see if this instance needs to be upgrade to another version and do so if needed
    # raises an OpenChain::UpgradeFailure if there are any problems
    def self.upgrade_if_needed callbacks = {}
      result = false
      if MasterSetup.need_upgrade?
        result = upgrade MasterSetup.get(false).target_version, false, callbacks
      end
      result
    end

    # Don't change the argument order or method name without also consulting
    # delayed_jobs_intializers.
    def self.upgrade_delayed_job_if_needed
      result = false
      if MasterSetup.need_upgrade?
        result = upgrade MasterSetup.get(false).target_version, true
      end
      result
    end

    def self.in_progress?
      File.exist?(upgrade_file_path)
    end

    def self.errored?
      File.exist?(upgrade_error_file_path)
    end

    def self.upgrade_file_path
      "tmp/upgrade_running.txt"
    end

    def self.upgrade_error_file_path
      "tmp/upgrade_error.txt"
    end

    # This tells use what the current version the system has already been upgraded to.  This CAN differ
    # from what the codebase (and even config/version.txt) indicates due to the multi-process/threaded nature
    # of our app server (Passenger).  In essence, what we'll do is once the upgrade is complete, it will echo
    # the version number to this file, thus any other threads will know this system has definitely already been upgraded.
    def self.current_upgraded_version
      Pathname.new(upgraded_version_path).read.strip rescue nil
    end

    def self.upgraded_version_path
      "tmp/upgraded_version.txt"
    end

    def already_upgraded?
      self.class.current_upgraded_version == @target
    end

    # do not initialize this method directly, use the static #upgrade method instead
    def initialize target
      @target = target
      @log_path = MasterSetup.instance_directory.join("log").join("#{Time.zone.now.strftime("%Y_%m_%d_%H_%M")}_#{target}.log")
    end

    # do not call this directly, use the static #upgrade method instead
    def go delayed_job_upgrade, callbacks = {}
      # Make sure only a single process is checking for and creating the upgrade file at a time
      # to avoid multiple upgrades running on the same host/customer instance at a time.
      @log = nil
      @upgrade_log = nil
      unless Upgrade.upgraded?
        Lock.acquire(Lock::UPGRADE_LOCK) do
          unless Upgrade.in_progress? || self.already_upgraded?
            @log = Logger.new(@log_path)
            # The log statement for this commeand will get sucked into the upgrade log when it's created
            capture_and_log "touch #{Upgrade.upgrade_file_path}"
          end
        end
      end

      return false unless @log

      Lock.acquire("Upgrade-#{MasterSetup.hostname}-#{@target}", yield_in_transaction: false) do
        # There's some (albeit really small) possibility that the upgrade could already have been done in another process
        # while waiting on this lock, just check the already_upgraded? and return if it has already been
        return false if self.already_upgraded?

        return do_upgrade(delayed_job_upgrade, callbacks)
      end
    end

    def do_upgrade delayed_job_upgrade, callbacks
      execute_callback(callbacks, :running)
      upgrade_completed = false
      begin
        @upgrade_log = InstanceInformation.check_in.upgrade_logs.create(:started_at=>0.seconds.ago, :from_version=>MasterSetup.current_code_version, :to_version=>@target, :log=>IO.read(@log_path))
        execute_callback(callbacks, :fs_running, MasterSetup.get.system_code, @upgrade_log.to_version)
        get_source
        apply_upgrade
        # upgrade_running.txt will stick around if one of the previous methods blew an exception
        # this is on purpose, so upgrades won't kick off if we're in an indeterminent failed state
        capture_and_log "rm #{Upgrade.upgrade_file_path}"
        # Remove the upgrade error file if it is present
        capture_and_log("rm #{Upgrade.upgrade_error_file_path}") if delayed_job_upgrade && File.exist?(Upgrade.upgrade_error_file_path)

        @@upgraded = true
        restart_app_server
        upgrade_completed = true
      rescue => e
        # If the delayed job upgrade fails at some point we'll need to remove the upgrade_running.txt file in order to get the upgrade
        # to start again, however, if we do that the dj_monitor.sh script may actually restart delayed job queues prior to the environment being ready for that.
        # Therefore, use the presence of another upgrade_error.txt flag file to tell it not to start the queue.
        capture_and_log "touch #{Upgrade.upgrade_error_file_path}" if delayed_job_upgrade
        # There's not a lot of point to logging an error on an upgrade, since the notification queue will, in all likelihood
        # not be running (since it's updating too, and if it fails will likely be due to the same thing that failed this instance).
        # Send via slack.
        ms = MasterSetup.get
        send_slack_failure(ms, e) if MasterSetup.production_env?
        execute_callback(callbacks, :fs_error, error_message(ms, e))
        raise e
      ensure
        finish_upgrade_log
        execute_callback(callbacks, :fs_finished, @upgrade_log)
      end

      upgrade_completed
    end

    def err_logger
      begin
        yield
      rescue => e
        e.log_me
      end
    end

    # private
    def finish_upgrade_log
      @upgrade_log.update(:finished_at=>0.seconds.ago, :log=>IO.read(@log_path)) if !@upgrade_log.nil? && File.exist?(@log_path)
    end

    def get_source
      log_me "Fetching source"
      capture_and_log 'git fetch'
      # This should clean up any files marked as modified, this should ONLY ever happen on test branches, where if a file is deleted (or ignored) and branches are flipped
      # between you might get a situation where on a branch it shows as modified.
      log_me "Fetch complele, cleaning up."
      capture_and_log 'git reset --hard HEAD'
      log_me "Reset complete, checking out #{@target}"
      capture_and_log "git checkout #{@target}"
      log_me "Source checked out"
      update_configuration_files
      log_me "Running bundle install"
      # Use the frozen command to absolutely prevent updates to Gemfile.lock in production (.ie should a Gemfile
      # update get checked in sans Gemfile.lock update)
      if MasterSetup.production_env?
        capture_and_log "bundle check || bundle install --frozen --without=development test"
      else
        capture_and_log "bundle install"
      end
    end

    def apply_upgrade
      migrate
      precompile
      init_schedulable_jobs
      update_master_setup_cache
      log_me "Writing '#{@target}' to #{OpenChain::Upgrade.upgraded_version_path}"
      File.open(OpenChain::Upgrade.upgraded_version_path, "w") {|f| f << "#{@target}\n" }
      log_me "Upgrade complete"
    end

    def restart_app_server
      # Passenger watches the tmp/restart.txt file and will restart the app instance if the timestamp on the file changes.
      # So just touch the file and the instance we updated will restart.
      log_me "Touching restart.txt"
      capture_and_log "touch tmp/restart.txt"
    end

    def init_schedulable_jobs
      load 'app/models/schedulable_job.rb' # get latest code
      SchedulableJob.create_default_jobs!
    end

    def update_configuration_files
      # Prefix the RAILS_ENV to this command because it doesn't fully load the rails environment but we do want
      # the RAILS_ENV var set for it.

      # The swallow errors below is here primarily because when flipping back and forth in test the branches may not have these rake tasks
      # This should probably be removed once all test branches can reliably be assumed to have these tasks
      swallow_errors = !MasterSetup.get.production?
      capture_and_log(prefix_env_variables("rake environment:build", {"RAILS_ENV" => MasterSetup.rails_env, "SSM_PARAMETER_STORE_NAMESPACE" => OpenChain::LoadEnvironment.configuration_namespace}), swallow_errors: swallow_errors)
      capture_and_log("rake environment:download_configs", swallow_errors: swallow_errors)
    end

    def add_rails_env command
      prefix_env_variables(command, {"RAILS_ENV" => MasterSetup.rails_env})
    end

    def prefix_env_variables command, variables
      command_line = []
      variables.each_pair do |key, value|
        command_line << "#{key}=#{value}"
      end
      command_line << command

      command_line.join(" ")
    end

    def migrate
      c = 0
      begin
        # Since we have the ability to clear the migration lock wait if we need to, I'm just going to set this to a long wait time
        # of an hour.  We do have migrations on large tables that can take 20+ minutes, so I don't really want to fail on those.
        while !MasterSetup.get_migration_lock && c < 3600
          # Don't need to log every single sleep/wait iteration
          log_me "Waiting for #{MasterSetup.get.migration_host} to release migration lock" if c % 10 == 0
          sleep 1
          c += 1
        end
        raise UpgradeFailure.new("Migration lock wait timed out.") unless MasterSetup.get_migration_lock
        capture_and_log "rake db:migrate"
        capture_and_log "rake data:migrate"
      ensure
        MasterSetup.release_migration_lock
      end
      log_me "Migration complete"
    end

    def capture_and_log command, swallow_errors: false
      stdout, stderr, status = Open3.capture3(command)
      log_me stdout unless stdout.blank?
      log_me stderr unless stderr.blank?
      raise UpgradeFailure.new("#{command} failed: #{stderr}") unless swallow_errors || status.success?
    end

    def precompile
      log_me "Precompiling assets"
      command = "rake assets:precompile"
      if !MasterSetup.production_env?
        command = add_rails_env command
      end
      capture_and_log command
      log_me "Precompile complete"
    end

    def update_master_setup_cache
      MasterSetup.clear_cache
      log_me "Cleared Master Setup Cache"
    end

    def send_slack_failure master_setup, error=nil
      begin
        msg = error_message master_setup, error
        slack_client.send_message('it-dev-notifications', msg, {icon_emoji:':loudspeaker:'})
      rescue => e
        # don't interrupt, just log
        e.log_me
      end
    end

    def error_message master_setup, error=nil
      msg = "<!group>: Upgrade failed for server: #{MasterSetup.hostname}, instance: #{master_setup.system_code}"
      msg << ", error: #{error.message}" if error
    end

    def slack_client
      OpenChain::SlackClient.new
    end

    def log_me txt
      @log.info txt
      @upgrade_log.update_attributes(:log=>IO.read(@log_path)) if !@upgrade_log.nil? && File.exist?(@log_path)
    end

    def execute_callback callback_hash, event, *event_params
      callbacks = Array.wrap(callback_hash.try(:[], event))
      callbacks.each do |cb|
        if cb.arity.zero?
          cb.call
        else
          params = event_params.take(cb.arity)
          cb.call(*params)
        end
      end
    end

  end

  class UpgradeFailure < StandardError; end
end
