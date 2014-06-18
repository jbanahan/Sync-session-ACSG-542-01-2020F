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

    # get the next time in UTC that this schedule should be executed
    def next_run_time
      base_time = self.last_start_time.nil? ? self.created_at : self.last_start_time
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
        while !run_day?(next_time_local)
          next_time_local += 1.day
        end

        return next_time_local.utc
      else
        # We can just use the previous run time and then add the interval string to it to determine the next run time
        interval_time = parse_time_string self.interval

        # If no interval time is returned and no run day is set, then we don't actually want to run the job, return nil
        return nil unless interval_time > 0 && run_day_set?

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

    #run the job if it should be run (next scheduled time < now & not already run by another thread)
    def run_if_needed log=nil
      if needs_to_run?
        update_count = self.class.where(:id=>self.id,:last_start_time=>self.last_start_time).update_all(["last_start_time = ?",Time.now])
        if update_count == 1
          self.run log
        end
      end
    end

    def needs_to_run? 
      self.next_run_time < Time.now.utc
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
      # This is all cribbed from the Rufus scheduler project, rather than import
      # it since, we'd like to ultimately remove the project altogether.

      # Turns a string like '1m10s' into a float like '70.0', more formally,
      # turns a time duration expressed as a string into a Float instance
      # (millisecond count).
      #
      # w -> week
      # d -> day
      # h -> hour
      # m -> minute
      # s -> second
      # M -> month
      # y -> year
      # 'nada' -> millisecond
      #
      # Some examples :
      #
      #   parse_time_string "0.5"    # => 0.5
      #   parse_time_string "500"    # => 0.5
      #   parse_time_string "1000"   # => 1.0
      #   parse_time_string "1h"     # => 3600.0
      #   parse_time_string "1h10s"  # => 3610.0
      #   parse_time_string "1w2d"   # => 777600.0
      #
      # Note will call #to_s on the input "string", so anything that is a String
      # or responds to #to_s will be OK.
      #
      def parse_time_string(string)
        string = string.to_s

        return 0.0 if string == ''

        m = string.match(/^(-?)([\d\.#{DURATION_LETTERS}]+)$/)

        raise ArgumentError.new("cannot parse '#{string}'") unless m

        mod = m[1] == '-' ? -1.0 : 1.0
        val = 0.0

        s = m[2]

        while s.length > 0
          m = nil
          if m = s.match(/^(\d+|\d+\.\d*|\d*\.\d+)([#{DURATION_LETTERS}])(.*)$/)
            val += m[1].to_f * DURATIONS[m[2]]
          elsif s.match(/^\d+$/)
            val += s.to_i / 1000.0
          elsif s.match(/^\d*\.\d*$/)
            val += s.to_f
          else
            raise ArgumentError.new("cannot parse '#{string}' (especially '#{s}')")
          end
          break unless m && m[3]
          s = m[3]
        end

        mod * val
      end
    end

    DURATIONS2M ||= [
      [ 'y', 365 * 24 * 3600 ],
      [ 'M', 30 * 24 * 3600 ],
      [ 'w', 7 * 24 * 3600 ],
      [ 'd', 24 * 3600 ],
      [ 'h', 3600 ],
      [ 'm', 60 ],
      [ 's', 1 ]
    ]

    DURATIONS ||= DURATIONS2M.inject({}) { |r, (k, v)| r[k] = v; r }
    DURATION_LETTERS ||= DURATIONS.keys.join
end
