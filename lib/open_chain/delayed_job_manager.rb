class DelayedJobManager

  #check the operating system to see if delayed_job worker process(es) are running for this instance
  def self.running?
    #use ps command to get all running processes filtered by "delayed_job", then make each row its own element in an array
    ps_jobs = %x{ps -Ao pid,args | grep delayed_job}.strip.split("\n")
    #split each row in the array into compontent elements so we end up with an array of arrays like
    #[[pid,command,other stuff],[pid,command,other stuff]]
    split_jobs = ps_jobs.collect {|j| j.strip.split}
    found = false
    #for each job, if the command (sj[1]) was exactly "delayed_job", use the pwdx command to see if it was launched from our
    #Rails.root directory.  If it was, then we know it's for this instance, so return true.  If not, then it's a different instance's worker, so keep moving
    split_jobs.each do |sj|
      if !found && sj[1]=="delayed_job"
        found = true if %x(pwdx #{sj[0]}).split[1].strip==Rails.root.to_s
      end
    end
    found
  end

  #execute the system command to start the delayed_job worker process
  def self.start
    `script/delayed_job start`
  end

  #execute the system command to stop the delayed_job worker process
  def self.stop
    `script/delayed_job stop`
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
end
