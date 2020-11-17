# == Schema Information
#
# Table name: survey_subscriptions
#
#  created_at :datetime         not null
#  id         :integer          not null, primary key
#  survey_id  :integer
#  updated_at :datetime         not null
#  user_id    :integer
#

class SurveySubscription < ActiveRecord::Base
  belongs_to :survey
  belongs_to :user
end
