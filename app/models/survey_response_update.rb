# == Schema Information
#
# Table name: survey_response_updates
#
#  created_at         :datetime         not null
#  id                 :integer          not null, primary key
#  survey_response_id :integer
#  updated_at         :datetime         not null
#  user_id            :integer
#
# Indexes
#
#  index_survey_response_updates_on_survey_response_id_and_user_id  (survey_response_id,user_id) UNIQUE
#  index_survey_response_updates_on_user_id                         (user_id)
#

class SurveyResponseUpdate < ActiveRecord::Base
  attr_accessible :survey_response_id, :user_id, :user, :updated_at

  belongs_to :user
  belongs_to :survey_response

  validates :user, presence:true
  validates :survey_response, presence:true

  scope :update_eligible, -> { where('updated_at < ?', 1.hour.ago) }

  def self.run_schedulable
    run_updates
  end

  # send all user updates for update_eligible items
  # this sends emails in the thread so it should be called in delayed_job
  def self.run_updates
    # Get the updates that are needed one at a time. They may be deleted while this is inside the loop
    # so don't pre-load them
    sru = SurveyResponseUpdate.update_eligible.first
    while !sru.nil?
      Lock.acquire("SurveyResponseUpdate-#{sru.survey_response_id}", temp_lock: true) do # only one thread should be working on each response
        # load all updates from DB so we have the freshest copy
        sr = SurveyResponse.find(sru.survey_response_id)
        updates = sr.survey_response_updates.update_eligible
        next if updates.empty? # must have been handled by another thread while we were waiting for the lock
        send_subscription_updates sr, updates
        send_user_update sr, updates
        updates.destroy_all
      end
      sru = SurveyResponseUpdate.update_eligible.first
    end
  end

  private
  def self.send_user_update sr, updates
    return if sr.status == sr.class::STATUSES[:needs_rating]
    return if updates.length==1 && updates.first.user == sr.user
    OpenMailer.send_survey_user_update(sr).deliver_now
  end
  def self.send_subscription_updates survey_response, updates
    subs = survey_response.survey.survey_subscriptions.to_a
    if updates.size == 1 # if there is only one update delete subscription for the user who made the update
      subs.delete_if {|s| s.user == updates.first.user}
    end
    return if subs.empty? # nothing to send
    OpenMailer.send_survey_subscription_update(survey_response, updates, subs).deliver_now
  end
end
