# == Schema Information
#
# Table name: business_validation_scheduled_jobs
#
#  business_validation_schedule_id :integer
#  created_at                      :datetime         not null
#  id                              :integer          not null, primary key
#  run_date                        :datetime
#  updated_at                      :datetime         not null
#  validatable_id                  :integer
#  validatable_type                :string(255)
#

class BusinessValidationScheduledJob < ActiveRecord::Base
  attr_accessible :business_validation_schedule_id, :run_date, :validatable_id, :validatable_type
  
  belongs_to :business_validation_schedule
  belongs_to :validatable, polymorphic: true
end
