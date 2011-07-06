class MilestonePlan < ActiveRecord::Base
  has_many :piece_sets
  has_many :milestone_definitions, :dependent => :destroy, :autosave=>true

  validates :name, :presence=>true
  validate :only_one_starting_definition
  validate :only_one_finish_definition

  after_save :update_plans

  accepts_nested_attributes_for :milestone_definitions

  def build_forecasts piece_set
    #preload existing forecasts to avoid N+1 calls
    ms = piece_set.milestone_forecast_set
    ms = piece_set.build_milestone_forecast_set if ms.nil?
    existing_forecasts = {}
    ms.milestone_forecasts.each do |ef|
      existing_forecasts[ef.milestone_definition_id] = ef
    end
    self.milestone_definitions.each do |md|
      f = existing_forecasts[md.id]
      f = ms.milestone_forecasts.build(:milestone_definition=>md) if f.nil?
      f.forecast = md.forecast piece_set
      f.planned = md.plan piece_set unless f.planned
    end
  end

  def starting_definition
    self.milestone_definitions.each do |md|
      return md if md.previous_milestone_definition_id.nil?
    end
  end

  private
  def only_one_starting_definition
    found_starting = false
    self.milestone_definitions.each do |md|
      if md.previous_milestone_definition_id.nil?
        if found_starting
          errors.add(:base, "You can only have one starting milestone.")
          return
        else
          found_starting = true 
        end
      end
    end
  end
  def only_one_finish_definition
    found_finish = false
    self.milestone_definitions.each do |md|
      if md.final_milestone?
        if found_finish
          errors.add(:base, "You can only have one final milestone.")
          return
        else
          found_finish = true
        end
      end
    end
  end
  def update_plans
    PieceSet.where(:milestone_plan_id=>self.id).each {|ps| ps.create_forecasts}
  end
end
