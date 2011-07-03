class MilestoneForecast < ActiveRecord::Base

  ORDERED_STATES = ["Achieved","Pending","Unplanned","Missed","Trouble","Overdue"]

  belongs_to :milestone_definition
  belongs_to :milestone_forecast_set

  validates_presence_of :milestone_definition
  validates_presence_of :milestone_forecast_set

  before_save :set_state

  alias_method :original_milestone_forecast_set_method, :milestone_forecast_set

  def milestone_forecast_set
    #overridden to find objects that have not been saved
    # http://www.agilereasoning.com/2008/04/26/using-belongs_to-in-rails-model-validations-when-the-parent-is-unsaved/
    m = original_milestone_forecast_set_method
    if m.nil?
      ObjectSpace.each_object(MilestoneForecastSet) {|mfs| m = mfs if m.nil? && mfs.new_record? && mfs.milestone_forecasts.include?(self) }
    end
    m
  end

  def actual
    self.milestone_definition.actual self.milestone_forecast_set.piece_set
  end

  def overdue?
    return false unless actual.nil? && !planned.nil?
    return planned < Time.now.utc.to_date
  end

  def previous_milestone_forecast
    my_def = self.milestone_definition
    prev_def = my_def.previous_milestone_definition
    return nil if prev_def.nil?
    my_set = self.milestone_forecast_set
    return my_set.find_forecast_by_definition prev_def
  end

  def set_state
    if self.planned.nil?
      self.state = "Unplanned" 
    else
      act = self.actual
      if act.nil?
        if planned < Time.now.utc.to_date
          self.state = "Overdue"
        else
          self.state = overdue_in_chain?(self) ? "Trouble" : "Pending"
        end
      else
        self.state = planned.to_date >= act.to_date ? "Achieved" : "Missed"
      end
    end
    self.state
  end

  private
  def overdue_in_chain? mf
    return true if mf.overdue?
    pm = mf.previous_milestone_forecast
    return overdue_in_chain? pm unless pm.nil?
    return false
  end
end
