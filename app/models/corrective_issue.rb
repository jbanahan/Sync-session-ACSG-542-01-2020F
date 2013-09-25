class CorrectiveIssue < ActiveRecord::Base
  belongs_to :corrective_action_plan, inverse_of: :corrective_issues
  attr_accessible :action_taken, :description, :suggested_action

  def html_description
    mdown description
  end

  def html_suggested_action
    mdown suggested_action
  end

  def html_action_taken
    mdown action_taken
  end

  private
  def mdown t
    return '' if t.blank?
    RedCloth.new(t).to_html.html_safe
  end
end
