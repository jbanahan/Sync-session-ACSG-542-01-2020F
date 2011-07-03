class MilestoneDefinition < ActiveRecord::Base
  include HoldsCustomDefinition

  belongs_to :milestone_plan
  belongs_to :previous_milestone_definition, :class_name=>"MilestoneDefinition"
  has_many :next_milestone_definitions, :class_name=>"MilestoneDefinition", :foreign_key=>"previous_milestone_definition_id"
  has_many :milestone_forecasts, :dependent=>:destroy

  validates_presence_of :model_field_uid

  def forecast piece_set
    av = MilestoneDefinition.last_actual piece_set, self
    return nil if av[1].nil?
    return av[1] if av[0]==self
    days_to_add = self.days_after_previous
    md = self.previous_milestone_definition
    while !md.nil?
      if md==av[0]
        return av[1] + days_to_add.days
      else
        days_to_add += md.days_after_previous
      end
      md = md.previous_milestone_definition
    end
  end

  def plan piece_set
    return actual(piece_set) if self.previous_milestone_definition.nil?
    days_to_add = self.days_after_previous
    md = self.previous_milestone_definition
    start_date = nil
    while !md.nil?
      if md.previous_milestone_definition.nil?
        start_date = md.actual(piece_set)
      else
        days_to_add += md.days_after_previous
      end
      md = md.previous_milestone_definition 
    end
    return start_date.nil? ? nil : start_date + days_to_add.days
  end

  def actual piece_set
    ModelField.find_by_uid(self.model_field_uid).export_from_piece_set(piece_set)
  end

  private
  def self.first_definition_in_plan milestone_def
    return milestone_def if milestone_def.previous_milestone_definition.nil?
    return first_definition_in_plan(milestone_def.previous_milestone_definition)
  end
  def self.last_actual piece_set, milestone_def
    av = [milestone_def, milestone_def.actual(piece_set)]
    if av[1].nil? && !milestone_def.previous_milestone_definition.nil?
      av = MilestoneDefinition.last_actual piece_set, milestone_def.previous_milestone_definition
    end
    av
  end

end
