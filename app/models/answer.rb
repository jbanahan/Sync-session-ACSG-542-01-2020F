class Answer < ActiveRecord::Base
  belongs_to :survey_response
  belongs_to :question
  has_many :answer_comments, :inverse_of=>:answer, :dependent=>:destroy
  has_many :attachments, :as=>:attachable, :dependent=>:destroy
  
  validates_presence_of :survey_response
  validates_presence_of :question

  accepts_nested_attributes_for :answer_comments, :reject_if => lambda {|q|
    q[:content].blank? || q[:user_id].blank? || !q[:id].blank?
  }
  accepts_nested_attributes_for :attachments, :reject_if => lambda {|q|
    q[:attached].blank?
  }

  def can_view? user
    self.survey_response && self.survey_response.can_view?(user)
  end
end
