class SearchSchedule < ActiveRecord::Base
  belongs_to :search_setup
  
  def needs_run?

  end

  def next_run_time
    nrt = nil
    (0...6).each do |day|
      test_result = next_run_time_test day
      nrt = test_result if nrt.nil? || test_result < nrt
    end
    nrt
  end

  def is_running?
    if self.last_start_time.nil?
      return false
    elsif self.last_finish_time.nil?
      return true
    elsif self.last_start_time > self.last_finish_time
      return true
    else
      return false
    end
  end

  private

  def next_run_time_test target_day
    user_tz = self.search_setup.user.time_zone
    user_tz = 'Eastern Time (US & Canada)' if user_tz.nil?
    local_now = Time.now.in_time_zone user_tz
    last_target_day = last_day_of_week(target_day).days.ago
    last_target_time = Time.new(last_target_day.year,last_target_day.month,last_target_day.day,self.run_hour)
    Time.now if last_target_time.utc < last_run_time
    
  end
  def self.last_day_of_week(target_day)
    today = Time.now.wday
    diff = today - target_day
    diff = diff + 7 if diff < 0
    diff
  end
end
