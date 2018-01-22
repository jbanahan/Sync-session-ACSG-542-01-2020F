# == Schema Information
#
# Table name: corrective_action_plans
#
#  id                 :integer          not null, primary key
#  survey_response_id :integer
#  created_by_id      :integer
#  status             :string(255)
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_corrective_action_plans_on_created_by_id       (created_by_id)
#  index_corrective_action_plans_on_survey_response_id  (survey_response_id)
#

class CorrectiveActionPlan < ActiveRecord::Base
  belongs_to :survey_response
  belongs_to :created_by, :class_name => 'User'
  has_many   :comments, as: :commentable, dependent: :destroy, autosave: true
  has_many   :corrective_issues, dependent: :destroy, inverse_of: :corrective_action_plan, autosave: true
  
  attr_accessible :status, :created_by_id

  before_save :update_status
  before_destroy :dont_destroy_activated

  STATUSES ||= {new:'New',active:'Active',resolved:'Resolved'}

  STATUS_DEFINITIONS ||= {new:"The survey recipient cannot see the plan and does not get email notifications.",active:"The survey recipient is notified about the plan and can respond.",resolved:"The plan has been completed."}
  def log_update user
    self.survey_response.log_update(user) if self.status == STATUSES[:active]
  end
  def can_view? user
    self.survey_response.can_view?(user) && show_if_new?(user)
  end

  def can_edit? user
    self.survey_response.can_edit?(user) 
  end

  def can_delete? user
    (self.status.blank? || self.status == STATUSES[:new]) && self.can_edit?(user)
  end

  # Can the user update the Action Taken on the plan's corrective issues
  def can_update_actions? user
    assigned_user? user
  end

  def assigned_user? user
    survey_response.user == user
  end

  private
  def show_if_new? user
    self.status != STATUSES[:new] || !assigned_user?(user) || survey_response.can_edit?(user)
  end

  def update_status
    self.status = STATUSES[:new] if self.status.blank?
  end

  def dont_destroy_activated
    return false unless self.status==STATUSES[:new] || self.status.blank?
  end
end
