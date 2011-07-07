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
end
