class Answer < ActiveRecord::Base
  belongs_to :survey_response
  belongs_to :question
  
  validates_presence_of :survey_response
  validates_presence_of :question
end
