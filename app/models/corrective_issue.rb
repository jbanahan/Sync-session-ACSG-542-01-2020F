# == Schema Information
#
# Table name: corrective_issues
#
#  action_taken              :string(255)
#  corrective_action_plan_id :integer
#  created_at                :datetime         not null
#  description               :text(65535)
#  id                        :integer          not null, primary key
#  resolved                  :boolean
#  suggested_action          :text(65535)
#  updated_at                :datetime         not null
#
# Indexes
#
#  index_corrective_issues_on_corrective_action_plan_id  (corrective_action_plan_id)
#

class CorrectiveIssue < ActiveRecord::Base
  belongs_to :corrective_action_plan, inverse_of: :corrective_issues
  attr_accessible :action_taken, :description, :suggested_action,
    :resolved

  has_many :attachments, as: :attachable, dependent: :destroy

  def html_description
    mdown description
  end

  def can_attach?(user)
    self.corrective_action_plan.can_view?(user)
  end

  def html_suggested_action
    mdown suggested_action
  end

  def html_action_taken
    mdown action_taken
  end

  def can_view? user
    corrective_action_plan.can_view?(user) || corrective_action_plan.can_edit?(user)
  end

  private
  def mdown t
    return '' if t.blank?
    RedCloth.new(t).to_html.html_safe
  end
end
