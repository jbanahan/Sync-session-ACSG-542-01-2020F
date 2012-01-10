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
      raise "Delayed Job Queue Too Big: #{c} Items" if c > max_messages
    rescue
      @@dont_send_until = 30.minutes.from_now
      $!.log_me [], [], false #don't delay the send since we know that the queue is backed up
    end
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
