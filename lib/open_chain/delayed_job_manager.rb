class DelayedJobManager

  @@dont_send_until = 1.hour.ago #always send at the beginning

  #check the operating system to see if delayed_job worker process(es) are running for this instance
  def self.running?
    DelayedJobManager.find_running_job? "delayed_job"
  end

  def self.script_running?
    DelayedJobManager.find_running_job? "ruby", lambda {|command_array| command_array[2]=="script/delayed_job"}
  end

  #execute the system command to start the delayed_job worker process
  def self.start
    `script/delayed_job start`
  end

  #execute the system command to stop the delayed_job worker process
  def self.stop
    `script/delayed_job stop`
  end

  # call to "script/delayed_job restart &"
  def self.restart
    `script/delayed_job restart &`
  end

  #checks the 'tmp/restart.txt' & 'tmp/stop.txt' files to see if we should have a worker job running
  def self.should_be_running?
    #if the restart file doesn't exist, we probably just installed 
    #and shouldn't run the background jobs yet
    return false unless File.exists? 'tmp/restart.txt'

    #if the restart file exists and the stop file doesn't exist, then the 
    #background jobs should be running
    return true unless File.exists? 'tmp/stop.txt'

    #if we have a stop file then return true if the stop file's timestamp is before
    #the restart file's timestamp
    return File.new('tmp/stop.txt').mtime < File.new('tmp/restart.txt').mtime
  end

  # generate errors if delayed job backlog is too deep
  def self.monitor_backlog max_messages=30
    return if @@dont_send_until > 0.seconds.ago
    begin
      c = Delayed::Job.count
      oldest = Delayed::Job.find(:first, :order => 'created_at ASC')
      raise "#{MasterSetup.get.system_code} - Delayed Job Queue Too Big: #{c} Items" if c > max_messages and oldest and oldest.created_at < 15.minutes.ago 
    rescue
      @@dont_send_until = 30.minutes.from_now
      $!.log_me [], [], true #don't delay the send since we know that the queue is backed up
    end
  end
  
  # Reports on any errored delayed job (by raising and logging an exception)
  # Returns true if any error was reported, false otherwise
  def self.report_delayed_job_error min_reporting_age_minutes = 15

    # Don't bother sending emails for anything we've reported on less than 15 minutes ago
    # This lock is not a 100% foolproof way to prevent multiple instances from reporting
    # on the same errors at the same time.  To do that would require a DB lock/table which is
    # more work than we need to do at this time.

    last_error_sent = MasterSetup.get.last_delayed_job_error_sent
    return false if last_error_sent && last_error_sent > min_reporting_age_minutes.minutes.ago

    error_messages = []
    real_error_count = 0
    max_message_length = 500
    begin
      errored_jobs = Delayed::Job.where("last_error IS NOT NULL").order("created_at DESC")
      real_error_count = errored_jobs.length
      errored_jobs.each_with_index do |job, i| 
        break if i >= 50
        m = job.last_error.length < max_message_length ? job.last_error : job.last_error[0, max_message_length]
        error_messages << "Job Error: " + m
      end
      raise "#{MasterSetup.get.system_code} - #{real_error_count} delayed job(s) have errors." if real_error_count > 0
    rescue
      #Update the error sent time and then log the error (which sends an email out with our errors)
      MasterSetup.get.update_attributes(:last_delayed_job_error_sent => Time.now)
      $!.log_me error_messages, [], true
    end

    return real_error_count > 0
  end

  #reset the timer for throttling montior_backlog error messages
  def self.reset_backlog_monitor
    @@dont_send_until = 1.minute.ago
  end
  private
  def self.find_running_job? job_name, extra_check=lambda {|command_array| true}
    #use ps command to get all running processes filtered by "job_name", then make each row its own element in an array
    ps_jobs = %x{ps -Ao pid,args | grep #{job_name}}.strip.split("\n")
    #split each row in the array into compontent elements so we end up with an array of arrays like
    #[[pid,command,other stuff],[pid,command,other stuff]]
    split_jobs = ps_jobs.collect {|j| j.strip.split}
    found = false
    #for each job, if the command (sj[1]) was exactly "job_name", use the pwdx command to see if it was launched from our
    #Rails.root directory.  If it was, then we know it's for this instance, so return true.  If not, then it's a different instance's worker, so keep moving
    split_jobs.each do |sj|
      if !found && sj[1]==job_name && extra_check.call(sj)
        found = true if %x(pwdx #{sj[0]}).split[1].strip==Rails.root.to_s
      end
    end
    found
  end
end
