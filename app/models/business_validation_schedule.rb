# == Schema Information
#
# Table name: business_validation_schedules
#
#  created_at      :datetime         not null
#  id              :integer          not null, primary key
#  model_field_uid :string(255)
#  module_type     :string(255)
#  name            :string(255)
#  num_days        :integer
#  operator        :string(255)
#  updated_at      :datetime         not null
#

class BusinessValidationSchedule < ActiveRecord::Base
  attr_accessible :model_field_uid, :module_type, :name, :num_days, :operator

  has_many :search_criterions
  has_many :business_validation_scheduled_jobs
end
