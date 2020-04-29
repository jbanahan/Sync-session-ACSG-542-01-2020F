module OpenChain; class ScheduledJobMonitor

  def self.run_schedulable opts = {}
    jobs = long_running_jobs.map {|j| j.run_class}
    if jobs.length > 0
      job_list = jobs.map {|job| "<li>#{job}</li>"}.join(" ")
      body = ("<p>The following Scheduled #{"Job".pluralize(job_list.length)} on the #{MasterSetup.get.system_code} instance #{"has".pluralize(job_list.length)} been running for more than an hour:<br><ul>#{job_list}</ul></p>" +
            "<p>You can determine if the job is legitimately still running by checking the Master Setup page and seeing if a Delayed Job instance is still running the job.</p>" +
            "<p>If no job is still running, you must reset the running flag on the scheduled job edit page.</p>").html_safe

      OpenMailer.send_simple_html(email(opts), "[VFI Track] Long Running Jobs", body).deliver_now
    end
  end

  def self.email opts
    opts_email = Array.wrap(opts["email"])
    opts_email.length > 0 ? opts_email : OpenMailer::BUG_EMAIL
  end


  def self.long_running_jobs
    SchedulableJob.where(no_concurrent_jobs: true, running: true).where("stopped = 0 OR stopped IS NULL").where("last_start_time < ?", Time.zone.now - 1.hour)
  end

end; end