#CODE COPIED FROM: https://github.com/jmettraux/rufus-scheduler/issues/10/
require 'rufus/scheduler'
require 'open_chain/delayed_job_manager'
require 'open_chain/upgrade'
require 'open_chain/integration_client'
require 'open_chain/alliance_imaging_client'

def job_wrapper job_name, &block
  begin
    yield unless Rails.env=='test'
  rescue
    OpenMailer.send_generic_exception $!, ["Scheduled Job: #{job_name}"]
  end
end

def if_active_server &block
  yield 
end

def execute_scheduler
  # Create your scheduler here
  scheduler = Rufus::Scheduler.start_new  
  logger = Logger.new(Rails.root.to_s + "/log/scheduler.log")

  #register to be active server
  scheduler.every '10s' do 
    job_wrapper "Schedule Check In" do
      ScheduleServer.check_in if DelayedJobManager.should_be_running?
    end
  end

  #check for upgrades
  scheduler.every '30s' do
    job_wrapper "Upgrade Check" do
      if Rails.env=='production'
        OpenChain::Upgrade.upgrade_if_needed 
        OpenChain::Upgrade.delay.upgrade_delayed_job_if_needed
      end
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
        SearchSchedule.all.each {|ss| ss.delay.run_if_needed logger}
      else
        logger.info "Skipping scheduled job rebuild: Not production"
      end
    end
  end

  #launch listener for jobs from integration server
  if Rails.env == 'production'
    scheduler.in '1s' do
     OpenChain::IntegrationClient.go MasterSetup.get.system_code
    end
  end

  #monitor delayed job backlog
  scheduler.every '5m' do
    DelayedJobManager.monitor_backlog
  end

  scheduler.cron '0 23 * * *' do
    job_wrapper "Purges" do
      Message.purge_messages
      ReportResults.purge
    end
  end
  
  scheduler.every("5m") do
    OpenChain::AllianceImagingClient.delay.consume_images
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
main_logger.info "SCHEDULER START"
else # Only execute one scheduler
  #execute_scheduler 
end

