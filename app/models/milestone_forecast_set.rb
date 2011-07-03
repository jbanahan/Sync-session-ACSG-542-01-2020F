class MilestoneForecastSet < ActiveRecord::Base

  belongs_to :piece_set
  has_many :milestone_forecasts, :dependent=>:destroy, :autosave=>true

  validates_presence_of :piece_set

  before_save :set_state

  def set_state
    last = find_last_milestone_forecast
    if last
      last.set_state #in case it hasn't been set yet
      self.state = last.state
    else
      self.state = "Unplanned"
    end
  end

  def find_forecast_by_definition milestone_definition
    #searches in memory so it can be used with the build methods, not just create
    milestone_forecasts.each {|f| return f if f.milestone_definition==milestone_definition}
    nil
  end

  private
  def find_last_milestone_forecast
    r = nil
    self.milestone_forecasts.each do |f|
      r = f if f.milestone_definition.final_milestone?
    end
    if r.nil?
      self.milestone_forecasts.each do |f|
        p = f.planned
        r = f if !p.nil? && (r.nil? || r.planned.nil? || p > r.planned)
      end
    end
    r
  end

end
