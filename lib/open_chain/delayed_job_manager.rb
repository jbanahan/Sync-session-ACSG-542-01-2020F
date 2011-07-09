class DelayedJobManager

  def self.running?
    ps_jobs = %x{ps -Ao pid,args | grep delayed_job}.strip.split("\n")
    split_jobs = ps_jobs.collect {|j| j.strip.split}
    found = false
    split_jobs.each do |sj|
      if !found && sj[1]=="delayed_job"
        found = true if %x(pwdx #{sj[0]}).split[1].strip==Rails.root.to_s
      end
    end
    found
  end

  def self.start
    `script/delayed_job start`
  end

  def self.stop
    `script/delayed_job stop`
  end

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
