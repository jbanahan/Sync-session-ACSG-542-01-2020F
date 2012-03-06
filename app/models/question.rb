class Question < ActiveRecord::Base
  belongs_to :survey, :touch=>true
  
  validates_presence_of :survey
  validates :content, :length=>{:minimum=>10}
  validate :parent_lock

  default_scope :order => "questions.rank ASC, questions.id ASC"

  private
  def parent_lock
    errors[:base] << "Cannot save question because survey is missing or locked." if self.survey && self.survey.locked?
  end
end
