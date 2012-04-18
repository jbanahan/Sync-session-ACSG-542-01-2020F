class AnswerComment < ActiveRecord::Base
  belongs_to :user
  belongs_to :answer, :touch=>true
  
  validates_presence_of :user
  validates_presence_of :answer
  validates_presence_of :content
end
