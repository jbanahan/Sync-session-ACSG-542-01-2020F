class SurveyResponse < ActiveRecord::Base
  attr_protected :email_sent_date, :email_opened_date, :response_opened_date, :submitted_date, :accepted_date
  belongs_to :user
  belongs_to :survey
  has_many :answers, :inverse_of=>:survey_response
  has_many :questions, :through=>:survey

  validates_presence_of :survey
  validates_presence_of :user

  accepts_nested_attributes_for :answers, :allow_destroy=>false

  after_save :update_status

  def can_view? user
    return true if user.id==self.user_id
    return true if self.survey.company_id == user.company_id && user.edit_surveys?
    false
  end

  private
  def update_status
    s = "Incomplete"
    s = "Not Rated" if self.submitted_date
    s = "Needs Improvement" if self.submitted_date && !self.answers.where(:rating=>"Needs Improvement").empty?
    s = "Accepted" if s!="Needs Improvement" && self.submitted_date && self.answers.where(:rating=>"Accepted").count == self.answers.count
    if s!=self.status
      self.status = s
      self.save
    end
  end
end
