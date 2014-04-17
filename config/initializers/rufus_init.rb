#CODE COPIED FROM: https://github.com/jmettraux/rufus-scheduler/issues/10/
require 'rufus/scheduler'
require 'mono_logger'
require 'open_chain/delayed_job_manager'
require 'open_chain/upgrade'
require 'open_chain/integration_client'
require 'open_chain/alliance_imaging_client'
require 'open_chain/feed_monitor'
require 'open_chain/custom_handler/polo_ca_efocus_generator'
require 'open_chain/custom_handler/polo_efocus_product_generator'
require 'open_chain/custom_handler/fenix_product_file_generator'
require 'open_chain/custom_handler/das_product_generator'
require 'open_chain/stat_client'

def job_wrapper job_name, &block
  # Removed the exception handling since we're relying on the built in scheduler exception handling
  # Not going to get the job name in the scheduler's exception, but the backtrace should be plenty of info
  # to track the issue down.
  yield unless Rails.env=='test'
end

def if_active_server &block
  yield 
end

def execute_scheduler
  # Create your scheduler here
  scheduler = Rufus::Scheduler.start_new  
  logger = MonoLogger.new(Rails.root.join("log", "scheduler.log"))

  # Set an exception handler to just call the exception's log_me method so we can
  # track down issues
  def scheduler.handle_exception(job, exception) 
    exception.log_me
  end

  # This solely controls which job instance can run the integration client front-end.
  scheduler.every '1m' do 
    job_wrapper "Schedule Check In" do
      ScheduleServer.check_in if DelayedJobManager.should_be_running?
    end
  end

  #send stats to stats.vfitrack.net
  if Rails.env.production?
    scheduler.every '4h' do
      job_wrapper "StatClient" do
        OpenChain::StatClient.delay.run
      end
    end
  end

  #run business rules engine
  if Rails.env.production?
    scheduler.every '10m' do
      job_wrapper "BusinessValidationTemplate" do
        BusinessValidationTemplate.delay.create_all!(true)
      end
    end
  end

  #check for upgrades for the web servers (allow overlapping is supposed to only allow a single instance of this job to run on this scheduler)
  upgrade_job_options = {:tags => "Upgrade", :allow_overlapping => false}
  scheduler.every '30s', upgrade_job_options do
    job_wrapper "Upgrade Check" do
      if Rails.env=='production'
        upgrade_running = lambda do
          # Unschedule all job except the upgrade ones - this doesn't stop jobs in progress, just effectively
          # stops the scheduler from running re-running them after this moment
          jobs = scheduler.all_jobs.values
          jobs.each_entry {|j| j.unschedule unless j.try(:tags).try(:include?, upgrade_job_options[:tags])}

          # Wait till all running jobs aside from Upgrade jobs are completed.
          upgrade_job_ids = jobs.collect {|j| j.try(:tags).try(:include?, upgrade_job_options[:tags]) ? j.job_id : nil}.compact
          # Sleep for at most 10 seconds...there's really no job below that should run for more than a second or two
          # since they're all pretty much just kicking off delayed jobs anyway
          sleep_iterations = 0
          while sleep_iterations < 20 && jobs.select {|j| j.running && !upgrade_job_ids.include?(j.job_id)}.length > 0
            sleep 0.5
            sleep_iterations += 1
          end
        end

        # Don't kick off another upgrade if we've already upgraded
        unless OpenChain::Upgrade.upgraded?
          OpenChain::Upgrade.upgrade_if_needed running: upgrade_running
        end
      end
    end
  end

  # Check for upgrade to delayed job server
  scheduler.every '30s', upgrade_job_options do
    job_wrapper "Delayed Job Upgrade Check" do
      if Rails.env=='production'
        # Make sure the upgrades are set to be the "highest" priority so they jump to the 
        # front of the queue.  The lower the value, the higher priority the job gets in delayed_job
        OpenChain::Upgrade.delay(:priority=>-100).upgrade_delayed_job_if_needed
      end
    end
  end

  #check in for Instance Information table
  scheduler.in '1m' do
    job_wrapper "Instance Check In" do
      InstanceInformation.check_in
    end
  end

  scheduler.every '1h' do
    job_wrapper 'Survey Response Updates' do
      SurveyResponseUpdate.delay.run_updates
    end
  end
  #Rebuild official tariff use counts
  scheduler.every '12h' do
    job_wrapper "OfficialTariff Use Count Update" do
      OfficialTariff.delay.update_use_count if Delayed::Job.where("handler like '%update_use_count%'").all.empty?
    end
  end

  #Rebuild index to capture any saved schedules
  # Only queue those jobs that actually need to be run
  scheduler.every("10m") do
    job_wrapper "Search Schedule" do
      if Rails.env == "production"
        logger.info "#{Time.now}: Rebuilding search schedule jobs"
        # Work progressively through the search schedule list instead of all at once to cut down on 
        # duplicate job queueing across multiple schedulers
        SearchSchedule.find_in_batches(batch_size: 5) do |schedules|
          schedules.each {|ss| ss.delay.run_if_needed if ss.needs_to_run?}
        end
      else
        logger.info "Skipping scheduled job rebuild: Not production"
      end
    end
  end

  # Only queue those jobs that actually need to be run
  scheduler.every("3m") do
    job_wrapper "Schedulable Jobs" do
      if Rails.env == 'production'
        logger.info "#{Time.now}: Rebuilding scheduled jobs"
        # Work progressively through the scheduled job list instead of all at once to cut down on 
        # duplicate job queueing across multiple schedulers
        SchedulableJob.find_in_batches(batch_size: 5) do |schedules|
          schedules.each {|sj| sj.delay.run_if_needed if sj.needs_to_run?}
        end
      end
    end
  end

  #launch listener for jobs from integration server
  if Rails.env == 'production'
    scheduler.in '1s' do
     OpenChain::IntegrationClient.go MasterSetup.get.system_code
    end
  end

  #make sure we're receiving files as expected
  if Rails.env == 'production'
    scheduler.every '30m' do
      OpenChain::FeedMonitor.delay.monitor
    end
  end

  #monitor delayed job backlog and watch for delayed job errors
  scheduler.every '5m' do
    DelayedJobManager.monitor_backlog
    DelayedJobManager.report_delayed_job_error
  end

  scheduler.cron '0 23 * * *' do
    job_wrapper "Purges" do
      Message.delay.purge_messages
      ReportResult.delay.purge
    end
  end
  
  if MasterSetup.get.system_code == 'polo' && Rails.env == 'production'
    scheduler.every("60m") do
      ["RLAUREN","POLO","CLUBMONCO"].each do |cn|
        OpenChain::CustomHandler::FenixProductFileGenerator.new(cn).delay.generate
      end
    end
    scheduler.every("240m") do
      OpenChain::CustomHandler::PoloEfocusProductGenerator.new.delay.generate
    end
  end

  if MasterSetup.get.system_code == 'dasvfitracknet' && Rails.env == 'production'
    scheduler.every("60m") do
      OpenChain::CustomHandler::DasProductGenerator.new.delay.generate
    end
  end

  if MasterSetup.get.system_code == "www-vfitrack-net" && Rails.env == 'production'
    scheduler.every("5m") do
      OpenChain::AllianceImagingClient.delay.consume_images
      OpenChain::AllianceImagingClient.delay.consume_stitch_responses
      OpenChain::AllianceImagingClient.delay.send_outstanding_stitch_requests
    end
    scheduler.every("30m") do
      OpenChain::CustomHandler::PoloCaEfocusGenerator.new.delay.generate 
    end
    scheduler.every('60m') do
      begin
        eb = Company.find_by_alliance_customer_number 'EDDIE' #the product database is tied to the US importer
        OpenChain::CustomHandler::FenixProductFileGenerator.new('EDDIEBR', eb.id, true).delay.generate
      rescue
        $!.log_me ['Eddie Bauer Fenix File Generator Failed']
      end
    end
  end

end

# Create the main logger and set some useful variables.
main_logger = MonoLogger.new(Rails.root.join("log", "scheduler.log"))

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

