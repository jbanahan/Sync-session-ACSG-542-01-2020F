class SurveyResponse < ActiveRecord::Base
  attr_protected :email_sent_date, :email_opened_date, :response_opened_date, :submitted_date, :accepted_date
  belongs_to :user
  belongs_to :survey
  has_many :answers, :inverse_of=>:survey_response
  has_many :questions, :through=>:survey
  has_many :survey_response_logs, :dependent=>:destroy

  validates_presence_of :survey
  validates_presence_of :user

  accepts_nested_attributes_for :answers, :allow_destroy=>false

  before_save :update_status
  after_commit :send_notification

  def can_view? user
    return true if user.id==self.user_id
    return true if self.survey.company_id == user.company_id && user.edit_surveys?
    false
  end

  #send email invite to user
  def invite_user!
    OpenMailer.send_survey_invite(self).deliver!
    self.survey_response_logs.create(:message=>"Invite sent to #{self.user.email}")
  end

  def notify_subscribers
    OpenMailer.send_survey_update(self).deliver!
  end

  def send_notification
    self.delay.notify_subscribers if self.submitted_date
  end

  private
  def update_status
    s = "Incomplete"
    if self.submitted_date
      s = self.rating.blank? ? "Needs Rating" : "Rated"
    end
    self.status = s
  end
end
