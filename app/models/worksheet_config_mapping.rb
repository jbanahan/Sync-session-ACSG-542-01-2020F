class WorksheetConfigMapping < ActiveRecord::Base
  include HoldsCustomDefinition
  
  belongs_to :worksheet_config
end
