class ProjectDeliverable < ActiveRecord::Base
  belongs_to :assigned_to, class_name:'User'
  belongs_to :project, touch: true, inverse_of: :project_deliverables
  attr_accessible :description, :due_date, :end_date, :estimated_hours, :start_date, :assigned_to_id, :complete

  def can_view? u
    self.project.can_view? u
  end

  def can_edit? u
    self.project.can_edit? u
  end
end
