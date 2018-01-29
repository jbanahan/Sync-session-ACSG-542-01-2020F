# == Schema Information
#
# Table name: survey_subscriptions
#
#  id         :integer          not null, primary key
#  survey_id  :integer
#  user_id    :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class SurveySubscription < ActiveRecord::Base
  belongs_to :survey
  belongs_to :user
end
