require 'rufus/sc/rtime'
require 'rufus/sc/cronline'

module OpenChain
  #
  # Support for making an object schedulable.  
  #
  # Implementing class needs to have the following accessible attributes:
  #
  # * `last_start_time`
  # * `created_at`
  # * `id`
  #
  # Implementing class needs to implement `run(logger)` to do the actual work
  #
  # The following methods can be overriden for extra functionality
  # * `day_to_run` #if the schedule should only be executed on a specific day of the month (defaults to nil)
  # * `hour_to_run` #if the schedule should be run at a specific hour (defaults to midnight aka 0)
  # * `minute_to_run` #if the schedule should be run after a specific minute within the `hour_to_run` (defaults to 0)
  # * `sunday_active?`, `monday_active?`, etc #if the schedule should be run on a specifc day (each defaults to false)
  #
  # NOTE: The day of week methods are ignored if the day_to_run returns a value
  module ScheduleSupport

    # defaults to US Eastern time, override this method in the implementing class for user level time zone support
    def time_zone
      ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    end

    def day_to_run
      nil
    end

    def hour_to_run
      0
    end

    def minute_to_run
      0
    end

    def interval
      nil
    end

    def sunday_active?
      false
    end

    def monday_active?
      false
    end

    def tuesday_active?
      false
    end

    def wednesday_active?
      false
    end

    def thursday_active?
      false
    end

    def friday_active?
      false
    end

    def saturday_active?
      false
    end

    def allow_concurrency?
      true
    end

    # get the next time in UTC that this schedule should be executed
    def next_run_time
      return nil if self.respond_to?(:stopped?) && stopped?

      base_time = self.last_start_time.nil? ? self.created_at : self.last_start_time
      return nil unless base_time
      
      tz = time_zone
      tz = ActiveSupport::TimeZone[tz.to_s] unless tz.is_a?(ActiveSupport::TimeZone)
      local_base_time = base_time.in_time_zone(tz)

      if interval.blank?
        # Since we're dealing w/ a once a day schedule, we can return a value of tomorrow if the schedule
        # doesn't include a day of the month or day of week to run on and a time of day to run.

        # Returning nil basically since we have no actual way to determine now when the job should actually run next.
        return nil unless (day_to_run || run_day_set?) && !hour_to_run.nil?

        # Start from the last date the job ran (using run hour / minute from the schedule for the time component)
        # and walk forward one day at a time until we see the next run time occurs on a valid schedule day of month or week
        # and the time is greater than the start time.
        next_time_local = tz.local(local_base_time.year, local_base_time.month, local_base_time.day, hour_to_run, minute_to_run)
        while next_time_local <= local_base_time || !run_day?(next_time_local)
          next_time_local += 1.day
        end

        return next_time_local.utc
      elsif (cron = cron_string?(interval))
        next_run_time = cron.next_time local_base_time
        # Don't support the run days checkboxes, cron already supports them in the cron expression and trying to build 
        # support for our version w/ the checkboxes is a pain
        return next_run_time ? next_run_time.utc : nil
      else
        # We can just use the previous run time and then add the interval string to it to determine the next run time
        interval_time = parse_time_string self.interval

        # If no interval time is returned and no run day is set, then we don't actually want to run the job, return nil
        return nil unless interval_time && interval_time > 0 && run_day_set?

        # Now we need to see if we're allowed to run on the day that interval_time + last_run_time points to
        next_run_time = local_base_time + interval_time
        while !run_day?(next_run_time)
          # Advance a whole day forward to midnight of the next day, which would be the absolute earliest the interval 
          # might allow us to run at if we're not allowed to run today.
          next_run_time = (next_run_time.at_midnight + 1.day)
        end

        return next_run_time.utc
      end

    end

    #run the job if it should be run (next scheduled time < now & not already run by another process)
    def run_if_needed force_run: false
      need_run = false
      begin   
        # Make sure nothing else is trying to also check if this job should run at the exact same time
        Lock.acquire("ScheduleSupport-#{self.class}-#{self.id}", times: 3, temp_lock: true) do

          # Reload so we're sure we have the newest start time recorded (in the time we may have been
          # waiting on the lock another process could have updated the start time)
          self.reload
          if (force_run == true || needs_to_run?) && no_other_instance_running?
            need_run = true
            attributes = {last_start_time: Time.zone.now}
            attributes[:running] = true if track_running?

            self.update_attributes! attributes
          end
        end

        if need_run
          self.run
        end
      ensure
        # We can be reasonably sure that we won't be setting the running flag to false in cases 
        # were it really matters (.ie disabling concurrency) since once we've set the flag above
        # in this process nothing else is going to ever flip it to running.  In cases where we're allowing
        # concurrency, there's the potential for this flag to be wrong for a few moments at a time.  Doesn't really matter.
        self.update_attributes!(running: false) if track_running? && need_run
      end

      need_run
    end

    def needs_to_run? 
      next_run = self.next_run_time
      !next_run.nil? && next_run < Time.now.utc
    end

    def no_other_instance_running?
      allow_concurrency? || (track_running? && self.class.where(:id=>self.id, running: true).count == 0)
    end

    def track_running?
      self.has_attribute?(:running)
    end
    
    #is a run day set in the file
    def run_day_set?
      self.sunday_active? || 
      self.monday_active? ||
      self.tuesday_active? || 
      self.wednesday_active? ||
      self.thursday_active? ||
      self.friday_active? ||
      self.saturday_active?
    end

    #is the day of week for the given time a day that we should run the schedule
    def run_day? t
      if day_to_run
        return day_to_run == t.day
      end
      case t.wday
      when 0
        return self.sunday_active?
      when 1
        return self.monday_active?
      when 2
        return self.tuesday_active?
      when 3
        return self.wednesday_active?
      when 4
        return self.thursday_active?
      when 5
        return self.friday_active?
      when 6
        return self.saturday_active?
      end
    end

    private 
      def cron_string? value
        # Rufus cron uses granularity to the second, which is a pain in the butt if 
        # you're copying / pasting cron expressions from the web since it's nonstandard. 
	      # So, just prepend a 0 so expressions will run on the minute change.
        return Rufus::CronLine.new ("0 " + value) rescue nil
      end

      def parse_time_string value
        Rufus.parse_time_string(value) rescue nil
      end
  end
end
