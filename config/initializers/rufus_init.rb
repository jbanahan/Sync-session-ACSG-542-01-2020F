#CODE COPIED FROM: https://github.com/jmettraux/rufus-scheduler/issues/10/
require 'rufus/scheduler'
require 'open_chain/delayed_job_manager'
require 'open_chain/upgrade'

def job_wrapper job_name, &block
  begin
    yield unless Rails.env=='test'
  rescue
    OpenMailer.send_generic_exception $!, ["Scheduled Job: #{job_name}"]
  end
end

def if_active_server &block
  yield if ScheduleServer.active_schedule_server?
end

def execute_scheduler
  # Create your scheduler here
  scheduler = Rufus::Scheduler.start_new  
  logger = Logger.new(Rails.root.to_s + "/log/scheduler.log")

  #register to be active server
  scheduler.every '10s' do 
    job_wrapper "Schedule Check In" do
      ScheduleServer.check_in
    end
  end

  #check for upgrades
  scheduler.every '30s' do
    job_wrapper "Upgrade Check" do
      OpenChain::Upgrade.upgrade MasterSetup.get.target_version if Rails.env=="production" && MasterSetup.need_upgrade?
    end
  end

  #check in for Instance Information table
  scheduler.every '30s' do
    job_wrapper "Instance Check In" do
      InstanceInformation.check_in
    end
  end

  #Rebuild index to capture any saved schedules
  scheduler.every("10m") do
    job_wrapper "Search Schedule" do
      if Rails.env == "production"
        logger.info "#{Time.now}: Rebuilding search schedule jobs "
        SearchSchedule.unschedule_jobs scheduler, logger
        if_active_server {SearchSchedule.schedule_jobs scheduler, logger}
      else
        logger.info "Skipping scheduled job rebuild: Not production"
      end
    end
  end

  #make sure delayed job workers are running
  scheduler.every("30s") do
    job_wrapper "Delayed Job Monitor" do
      if DelayedJobManager.script_running?
        logger.info "#{Time.now}: Skipping delayed_job check. Script already running."
      else
        if DelayedJobManager.should_be_running? && !DelayedJobManager.running?
          logger.info "#{Time.now}: Starting delayed_job"
          DelayedJobManager.start
        elsif !DelayedJobManager.should_be_running? && DelayedJobManager.running?
          logger.info "#{Time.now}: Stopping delayed_job"
          DelayedJobManager.stop
        end
      end
      #monitor queue depth
      if DelayedJobManager.should_be_running?
        job_count = Delayed::Job.where("run_at < ?",15.minutes.ago).count
        if job_count > 0
          begin
            raise "#{job_count} jobs over 15 minutes old in delayed_job queue for #{Rails.root.to_s}"
          rescue
            $!.email_me [], [], false #don't delay the send (since we don't want it to go into the already backed up queue)
          end
        end
      end
    end
  end
  
  scheduler.cron '0 23 * * *' do
    job_wrapper "Messages Purge" do
      Message.purge_messages
    end
  end

  scheduler.every("3m") do
    job_wrapper "FTP Sweeper" do
      if_active_server do
        m = MasterSetup.first
        if m && m.system_code
          if m.ftp_polling_active?
            logger.info "#{Time.now}: Sweeping FTP folder."
            FtpWalker.new.go
            logger.info "#{Time.now}: FTP Sweep Complete"
          else
            logger.info "#{Time.now}: FTP disabled (polling flag off)"
          end
        else
          logger.info "#{Time.now}: FTP disabled (system code not configured)"
        end
      end
    end
  end
end

# Create the main logger and set some useful variables.
main_logger = Logger.new(Rails.root.to_s + "/log/scheduler.log")

if !File.directory?(Rails.root.to_s + "/tmp")
  Dir.mkdir(Rails.root.to_s + "/tmp")
end

if !File.directory?(Rails.root.to_s + "/tmp/pids")
  Dir.mkdir(Rails.root.to_s + "/tmp/pids")
end
  
pid_file = (Rails.root.to_s + "/tmp/pids/scheduler").to_s
File.delete(pid_file) if FileTest.exists?(pid_file)

if defined?(PhusionPassenger) then
  # Passenger is starting a new process
  PhusionPassenger.on_event(:starting_worker_process) do |forked| 
    # If we are forked and there's no pid file (that is no lock)
    if forked && !FileTest.exists?(pid_file) then
      main_logger.debug "SCHEDULER START ON PROCESS #{$$}"
      # Write the current PID on the file
      File.open(pid_file, "w") { |f| f.write($$) }
      # Execute the scheduler
      execute_scheduler
    end
  end

  # Passenger is shutting down a process.   
  PhusionPassenger.on_event(:stopping_worker_process) do
    # If a pid file exists and the process which 
    # is being shutted down is the same which holds the lock 
    # (in other words, the process which is executing the scheduler)
    # we remove the lock.
    if FileTest.exists?(pid_file) then
      if File.open(pid_file, "r") {|f| pid = f.read.to_i} == $$ then 
        main_logger.debug "SCHEDULER STOP ON PROCESS #{$$}"
        File.delete(pid_file)
      end
    end
  end
else # Only execute one scheduler
  execute_scheduler
end

main_logger.info "SCHEDULER START"
