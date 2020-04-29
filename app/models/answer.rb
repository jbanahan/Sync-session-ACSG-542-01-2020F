# == Schema Information
#
# Table name: answers
#
#  choice             :string(255)
#  created_at         :datetime         not null
#  id                 :integer          not null, primary key
#  question_id        :integer
#  rating             :string(255)
#  survey_response_id :integer
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_answers_on_question_id         (question_id)
#  index_answers_on_survey_response_id  (survey_response_id)
#

class Answer < ActiveRecord::Base
  attr_accessible :choice, :created_at, :question_id, :question,
    :rating, :survey_response_id, :survey_response, :updated_at, :answer_comments_attributes,
    :attachments_attributes

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

  def attachment_added attachment
    # updating the updated at time on the answer when an attachment is added to it will
    # mean the timestamp displayed on the screen is updated whenever someone attacheds a file
    # to the answer...which is good.
    self.touch
  end

  # Number of hours since last update
  def hours_since_last_update
    return 0 unless self.updated_at
    ((0.seconds.ago.to_i - self.updated_at.to_i) / 3600).to_i
  end
end
