class Answer < ActiveRecord::Base
  belongs_to :survey_response
  belongs_to :question
  has_many :answer_comments, :inverse_of=>:answer, :dependent=>:destroy
  
  validates_presence_of :survey_response
  validates_presence_of :question

  accepts_nested_attributes_for :answer_comments, :reject_if => lambda {|q|
    q[:content].blank? || q[:user_id].blank? || !q[:id].blank?
  }
end
