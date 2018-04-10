# == Schema Information
#
# Table name: questions
#
#  attachment_required_for_choices :string(255)
#  choices                         :text
#  comment_required_for_choices    :string(255)
#  content                         :text
#  created_at                      :datetime         not null
#  id                              :integer          not null, primary key
#  rank                            :integer
#  require_attachment              :boolean          default(FALSE)
#  require_comment                 :boolean          default(FALSE)
#  survey_id                       :integer
#  updated_at                      :datetime         not null
#  warning                         :boolean
#
# Indexes
#
#  index_questions_on_survey_id  (survey_id)
#

class Question < ActiveRecord::Base
  belongs_to :survey, touch: true, inverse_of: :questions
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

  def can_view? user
    return true if self.survey.can_view?(user)
    self.survey.survey_responses.each do |response|
      return true if response.can_view?(user)
    end
    return false
  end

  def require_attachment_for_choices
    self.attachment_required_for_choices.to_s.split(/\r?\n\s*/)
  end

  def require_comment_for_choices
    self.comment_required_for_choices.to_s.split(/\r?\n\s*/)
  end

  private
  def parent_lock
    errors[:base] << "Cannot save question because survey is missing or locked." if self.survey && self.survey.locked?
  end
end
