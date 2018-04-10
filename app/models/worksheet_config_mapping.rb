# == Schema Information
#
# Table name: worksheet_config_mappings
#
#  column               :integer
#  created_at           :datetime         not null
#  custom_definition_id :integer
#  id                   :integer          not null, primary key
#  model_field_uid      :string(255)
#  row                  :integer
#  updated_at           :datetime         not null
#  worksheet_config_id  :integer
#

class WorksheetConfigMapping < ActiveRecord::Base
  include HoldsCustomDefinition
  
  belongs_to :worksheet_config
end
