# == Schema Information
#
# Table name: answer_comments
#
#  id         :integer          not null, primary key
#  answer_id  :integer
#  user_id    :integer
#  content    :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  private    :boolean
#
# Indexes
#
#  index_answer_comments_on_answer_id  (answer_id)
#

class AnswerComment < ActiveRecord::Base
  belongs_to :user
  belongs_to :answer, :touch=>true
  
  validates_presence_of :user
  validates_presence_of :answer
  validates_presence_of :content
end
