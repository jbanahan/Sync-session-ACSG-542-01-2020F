class SearchSchedule < ActiveRecord::Base
  belongs_to :search_setup

  def cron_string
    return nil unless any_days_scheduled?
    tz = search_setup.user.time_zone
    "* #{run_hour} * * #{make_days_of_week} #{tz}"
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
  def any_days_scheduled?
    self.run_sunday || 
    self.run_monday ||
    self.run_tuesday ||
    self.run_wednesday ||
    self.run_thursday || 
    self.run_friday ||
    self.run_saturday
  end
  def make_days_of_week
    d = []
    d << "0" if self.run_sunday
    d << "1" if self.run_monday
    d << "2" if self.run_tuesday
    d << "3" if self.run_wednesday
    d << "4" if self.run_thursday
    d << "5" if self.run_friday
    d << "6" if self.run_saturday

    return CSV.generate_line(d,{:row_sep=>""})
  end

end
