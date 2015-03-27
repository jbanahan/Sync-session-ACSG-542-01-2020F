class Answer < ActiveRecord::Base
  belongs_to :survey_response, :touch=>true
  belongs_to :question
  has_many :answer_comments, inverse_of: :answer, dependent: :destroy, autosave: true
  has_many :attachments, :as=>:attachable, :dependent=>:destroy
  
  validates_presence_of :survey_response
  validates_presence_of :question

  accepts_nested_attributes_for :answer_comments, :reject_if => lambda {|q|
    q[:content].blank? || q[:user_id].blank? || !q[:id].blank?
  }
  accepts_nested_attributes_for :attachments, :reject_if => lambda {|q|
    q[:attached].blank?
  }

  # does the question have a multiple choice, comment or attachment associated with the survey response user
  def answered?
    !self.choice.blank? || !self.answer_comments.where(:user_id=>survey_response.user_id).blank? || !self.attachments.where(:uploaded_by_id=>survey_response.user_id).blank? 
  end

  def can_view? user
    self.survey_response && self.survey_response.can_view?(user)
  end

  def can_attach? user
    can_view? user
  end

  def log_update user
    self.survey_response.log_update user
  end

  # Number of hours since last update
  def hours_since_last_update
    return 0 unless self.updated_at
    ((0.seconds.ago.to_i - self.updated_at.to_i) / 3600).to_i
  end
end
