# This simple module's basic job is to keep track of the exact time
# the #poll method was last called and run to completion for the class
# this module is mixed into.  It's handy to use in scenarios where you need
# to look for things that have changed since the last time the code was run.
module OpenChain; module PollingJob

  # This method yields a start and an end time.  The start time is relative to
  # the last time this job ran (which is internally tracked by this method).
  # The end time is the current time.
  # 
  # The block this method yields to MUST run to completion for the last run
  # time to be updated.  If the block raises, the next call to poll will
  # return the same start time as the previous call that raised.
  #
  # If the polling_offset parameter is utilized then the yield start/end times
  # are offset back in time by the given number of seconds.  This is useful
  # for cases where you wish to poll a service but adjust the start/end times
  # back a couple seconds / minutes.
  def poll polling_offset: nil
    key = KeyJsonItem.polling_job(polling_job_name).first_or_create! json_data: "{}"
    data = key.data
    last_run = data['last_run']
    
    tz = ActiveSupport::TimeZone[timezone]
    raise "'#{timezone}' is not a valid TimeZone." if tz.nil?

    last_run = tz.parse(last_run.nil? ? null_start_time : last_run)
    run_time = tz.now

    offset_start = apply_offset(last_run, polling_offset)
    offset_end = apply_offset(run_time, polling_offset)

    result = yield offset_start, offset_end

    key.data = {'last_run' => run_time.iso8601}
    key.save!

    result
  end

  def timezone
    "UTC"
  end

  def polling_job_name
    # Handle cases where this module is both included and extended.
    if self.is_a? Class
      self.to_s
    else
      self.class.to_s
    end
  end

  def apply_offset time, offset
    if offset.to_i != 0
      time - offset.to_i.seconds
    else
      time
    end
  end

  def null_start_time
    # By default, the first polling job is basically going to end up as a no-op
    # since the blank start time will use now and the end time will be now.
    Time.zone.now.iso8601
  end

end; end;