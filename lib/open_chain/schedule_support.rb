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
      return Time.now.utc+1.day unless (day_to_run || run_day_set?) && !hour_to_run.nil?
      tz = time_zone
      tz_str = tz.name
      base_time = self.last_start_time.nil? ? self.created_at : self.last_start_time
      local_base_time = base_time.in_time_zone(tz_str)
      next_time_local = tz.local(local_base_time.year,local_base_time.month,local_base_time.day,hour_to_run,minute_to_run)
      while next_time_local < local_base_time || !run_day?(next_time_local)
        next_time_local += 1.day
      end
      next_time_local.utc
    end

    #run the job if it should be run (next scheduled time < now & not already run by another thread)
    def run_if_needed log=nil
      if self.next_run_time < Time.now.utc
        update_count = self.class.where(:id=>self.id,:last_start_time=>self.last_start_time).update_all(["last_start_time = ?",Time.now])
        if update_count == 1
          self.run log
        end
      end
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
  end
end
