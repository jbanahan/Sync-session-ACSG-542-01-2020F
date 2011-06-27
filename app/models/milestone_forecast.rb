class MilestoneForecast < ActiveRecord::Base
  belongs_to :milestone_definition
  belongs_to :piece_set
end
