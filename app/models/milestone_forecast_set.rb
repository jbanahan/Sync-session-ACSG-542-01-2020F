# == Schema Information
#
# Table name: milestone_forecast_sets
#
#  created_at   :datetime         not null
#  id           :integer          not null, primary key
#  piece_set_id :integer
#  state        :string(255)
#  updated_at   :datetime         not null
#
# Indexes
#
#  mfs_state          (state)
#  one_per_piece_set  (piece_set_id) UNIQUE
#

class MilestoneForecastSet < ActiveRecord::Base
  belongs_to :piece_set
  has_many :milestone_forecasts, :dependent=>:destroy, :autosave=>true

  validates_presence_of :piece_set

  before_save :set_state

  def as_json(opts={})
    super(:methods=>[:can_change_plan], :include=>{:milestone_forecasts=>{:methods=>[:label, :actual]}, :piece_set=>{:only=>:id, :methods=>[:identifiers]}})
  end

  def find_forecast_by_definition milestone_definition
    # searches in memory so it can be used with the build methods, not just create
    milestone_forecasts.each {|f| return f if f.milestone_definition==milestone_definition}
    nil
  end

  def set_state
    last = find_last_milestone_forecast
    if last
      last.set_state # in case it hasn't been set yet
      self.state = last.state
    else
      self.state = "Unplanned"
    end
  end

  # can the currently logged in user change the plan, doesn't end in ? for json/javascript compatibility
  def can_change_plan
    piece_set && User.current && piece_set.change_milestone_plan?(User.current)
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
