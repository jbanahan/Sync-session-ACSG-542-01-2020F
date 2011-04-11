#CODE COPIED FROM: https://github.com/jmettraux/rufus-scheduler/issues/10/
require 'rufus/scheduler'

def execute_scheduler
  # Create your scheduler here
  scheduler = Rufus::Scheduler.start_new  
  logger = Logger.new(Rails.root.to_s + "/log/scheduler.log")

  #Rebuild index to capture any saved schedules
  scheduler.every("10m") do
    if Rails.env == "production"
      logger.info "#{Time.now}: Rebuilding search schedule jobs "
      SearchSchedule.reset_schedule scheduler, logger
    else
      logger.info "Skipping scheduled job rebuild: Not production"
    end
  end
  scheduler.every("3m") do
    m = MasterSetup.first
    if m && m.system_code == 'www-vfitrack-net'
      FtpWalker.new.go
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
