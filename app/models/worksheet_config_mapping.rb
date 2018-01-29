# == Schema Information
#
# Table name: worksheet_config_mappings
#
#  id                   :integer          not null, primary key
#  row                  :integer
#  column               :integer
#  model_field_uid      :string(255)
#  custom_definition_id :integer
#  worksheet_config_id  :integer
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#

class WorksheetConfigMapping < ActiveRecord::Base
  include HoldsCustomDefinition
  
  belongs_to :worksheet_config
end
