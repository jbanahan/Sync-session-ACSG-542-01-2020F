class Question < ActiveRecord::Base
  belongs_to :survey, :touch=>true
  has_many :attachments, :as=>:attachable, :dependent=>:destroy
  
  validates_presence_of :survey
  validates :content, :length=>{:minimum=>10}
  validate :parent_lock

  default_scope :order => "questions.rank ASC, questions.id ASC"

  accepts_nested_attributes_for :attachments, :reject_if => lambda {|q|
    q[:attached].blank?
  }

  def html_content
    RedCloth.new(self.content).to_html.html_safe
  end
  def choice_list
    r = []
    r = self.choices.lines.collect {|l| l.strip.blank? ? nil : l.strip}.compact unless self.choices.blank?
    r
  end
  private
  def parent_lock
    errors[:base] << "Cannot save question because survey is missing or locked." if self.survey && self.survey.locked?
  end
end
