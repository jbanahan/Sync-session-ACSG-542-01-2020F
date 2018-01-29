# == Schema Information
#
# Table name: survey_responses
#
#  id                              :integer          not null, primary key
#  survey_id                       :integer
#  user_id                         :integer
#  email_sent_date                 :datetime
#  email_opened_date               :datetime
#  response_opened_date            :datetime
#  submitted_date                  :datetime
#  accepted_date                   :datetime
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#  status                          :string(255)
#  rating                          :string(255)
#  name                            :string(255)
#  address                         :text
#  phone                           :string(255)
#  fax                             :string(255)
#  email                           :string(255)
#  subtitle                        :string(255)
#  archived                        :boolean
#  expiration_notification_sent_at :datetime
#  base_object_type                :string(255)
#  base_object_id                  :integer
#  group_id                        :integer
#  checkout_by_user_id             :integer
#  checkout_token                  :string(255)
#  checkout_expiration             :datetime
#
# Indexes
#
#  index_survey_responses_on_base_object_type_and_base_object_id  (base_object_type,base_object_id)
#  index_survey_responses_on_rating                               (rating)
#  index_survey_responses_on_survey_id                            (survey_id)
#  index_survey_responses_on_user_id                              (user_id)
#

class SurveyResponse < ActiveRecord::Base
  attr_protected :email_sent_date, :email_opened_date, :response_opened_date, :submitted_date, :accepted_date, :archived, :expiration_notification_sent_at, :checkout_by_user, :checkout_token, :checkout_expiration
  belongs_to :user
  belongs_to :survey
  belongs_to :base_object, polymorphic: true, inverse_of: :survey_responses
  belongs_to :group
  has_many :answers, inverse_of: :survey_response, autosave: true
  has_many :questions, :through=>:survey
  has_many :survey_response_logs, :dependent=>:destroy
  has_many :survey_response_updates, :dependent=>:destroy
  has_many :tpp_orders, class_name: 'Order', foreign_key: 'tpp_survey_response_id'
  has_one :corrective_action_plan, :dependent=>:destroy
  belongs_to :checkout_by_user, class_name: "User"

  validates_presence_of :survey
  validates_presence_of :user, if: lambda {|sr| sr.group.nil?}, message: "User and Group can't be blank."
  validates_presence_of :group, if: lambda {|sr| sr.user.nil?}, message: "User and Group can't be blank."

  before_save :update_status

  STATUSES ||= {:incomplete => "Incomplete", :needs_rating => "Needs Rating", :rated => "Rated"}

  scope :was_archived, lambda {|ar| ar == true ? where("survey_responses.archived = ?", true) : where("survey_responses.archived IS NULL OR survey_responses.archived = ?", false)}
  scope :reminder_email_needed, lambda { joins(:survey).where("(expiration_notification_sent_at IS NULL) AND (ADDDATE(email_sent_date, surveys.expiration_days) < now())").readonly(false) }
  scope :not_expired, lambda { joins(:survey).where("surveys.expiration_days is null OR survey_responses.email_sent_date is null OR (ADDDATE(email_sent_date, surveys.expiration_days) > now())")}

  def survey_name
    return nil unless self.survey
    return self.survey.name
  end

  def long_name
    ln = self.survey_name
    ln = "" if ln.nil?
    ln = "#{ln} - #{self.subtitle}" unless self.subtitle.blank?
    ln
  end

  def log_update user
    self.survey_response_updates.where(user_id:user.id).first_or_create
  end
  # last time this user made an action that created a log message
  def last_logged_by_user u
    m = self.survey_response_logs.where(user_id:u.id).order('survey_response_logs.created_at DESC').limit(1).first
    m ? m.created_at : nil
  end
  # does the survey response or any of its questions have ratings
  def rated?
    !self.rating.blank? || !self.answers.where("rating is not null AND length(rating) > 0").empty?
  end

  def can_view? user
    assigned_to_user?(user) || user.company_id == self.survey.company_id
  end

  def assigned_to_user? user
    return user.id == self.user_id || (group && user.in_group?(group))
  end

  def responder_name
    group ? group.name : user.full_name
  end

  def most_recent_user_log
    survey_response_logs.where("user_id IS NOT NULL").order("updated_at DESC").first
  end

  def self.search_secure user, base
    r = nil
    if user.view_surveys?
      r = base.joins(:survey).where("survey_responses.user_id = :user_id OR surveys.company_id = :company_id",{user_id:user.id,company_id:user.company_id})
    else
      r = base.where(user_id:user.id)
    end
    r
  end

  def can_edit? user
    self.survey.company_id == user.company_id && user.edit_surveys? && !self.survey.archived?
  end

  #can the user view private comments for this survey
  def can_view_private_comments? user
    self.survey.company_id == user.company_id
  end

  #send email invite to user
  def invite_user!
    m = OpenMailer.send_survey_invite(self)
    m.deliver!
    unless self.email_sent_date #only set it the first time
      self.email_sent_date=0.seconds.ago
      self.save
    end
    # Since the emailer explodes out the email addresses
    # of group members assigned to this survey, pull
    # the email from the mail object, rather than the survey
    emails = m.to.join(", ")
    self.survey_response_logs.create(:message=>"Invite sent to #{emails}")
  end

  def clear_checkout
    self.checkout_by_user = nil
    self.checkout_token = nil
    self.checkout_expiration = nil
  end

  def checkout user, token
    self.checkout_by_user = user
    self.checkout_token = token
    self.checkout_expiration = Time.zone.now + 2.days
  end

  def self.run_schedulable
    clear_expired_checkouts Time.zone.now
  end

  def self.clear_expired_checkouts relative_to
    # Find all responses that have expired checkout times and clear them all
    integration = User.integration
    SurveyResponse.where("checkout_expiration < ? ", relative_to).each do |sr|
      sr.clear_checkout
      sr.save!
      sr.survey_response_logs.create!(message: "Check out expired.", user: integration)
    end
  end

  private
  def update_status
    s = STATUSES[:incomplete]
    if self.submitted_date
      s = self.rating.blank? ? STATUSES[:needs_rating] : STATUSES[:rated]
    end
    self.status = s
  end
end
