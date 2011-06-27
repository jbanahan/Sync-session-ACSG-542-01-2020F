class MilestoneForecast < ActiveRecord::Base
  belongs_to :milestone_definition
  belongs_to :piece_set

  def actual
    return nil if self.piece_set.blank? || self.milestone_definition.blank?
    self.milestone_definition.actual self.piece_set
  end

end
