class SurveyResponse < ActiveRecord::Base
  belongs_to :user
  belongs_to :survey
  has_many :answers, :inverse_of=>:survey_response

  validates_presence_of :survey
  validates_presence_of :user

  accepts_nested_attributes_for :answers, :allow_destroy=>false
end
