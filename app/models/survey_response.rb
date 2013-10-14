class SurveyResponse < ActiveRecord::Base
  attr_protected :email_sent_date, :email_opened_date, :response_opened_date, :submitted_date, :accepted_date, :archived
  belongs_to :user
  belongs_to :survey
  has_many :answers, :inverse_of=>:survey_response
  has_many :questions, :through=>:survey
  has_many :survey_response_logs, :dependent=>:destroy
  has_one :corrective_action_plan, :dependent=>:destroy

  validates_presence_of :survey
  validates_presence_of :user

  before_save :update_status
  after_commit :send_notification

  STATUSES ||= {:incomplete => "Incomplete", :needs_rating => "Needs Rating", :rated => "Rated"}

  scope :was_archived, lambda {|ar| ar == true ? where("survey_responses.archived = ?", true) : where("survey_responses.archived IS NULL OR survey_responses.archived = ?", false)}

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
    return true if user.id==self.user_id
    can_edit? user
  end
  
  def can_edit? user
    self.survey.company_id == user.company_id && user.edit_surveys?
  end

  #can the user view private comments for this survey
  def can_view_private_comments? user
    self.survey.company_id == user.company_id 
  end

  #send email invite to user
  def invite_user!
    OpenMailer.send_survey_invite(self).deliver!
    unless self.email_sent_date #only set it the first time
      self.email_sent_date=0.seconds.ago
      self.save
    end
    self.survey_response_logs.create(:message=>"Invite sent to #{self.user.email}")
  end

  def notify_subscribers corrective_action_plan = false
    OpenMailer.send_survey_subscription_update(self,corrective_action_plan).deliver! unless self.survey.survey_subscriptions.blank?
  end

  def send_notification
    self.delay.notify_subscribers if self.submitted_date
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
