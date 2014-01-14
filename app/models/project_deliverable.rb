class ProjectDeliverable < ActiveRecord::Base
  belongs_to :assigned_to, class_name:'User'
  belongs_to :project, touch: true, inverse_of: :project_deliverables
  attr_accessible :description, :due_date, :end_date, :estimated_hours, :start_date, :assigned_to_id, :complete

  scope :incomplete, where('complete is null or complete = ?',false)
  scope :overdue, incomplete.where('due_date < ?',0.seconds.ago.to_date)

  def can_view? u
    self.project.can_view? u
  end

  def can_edit? u
    self.project.can_edit? u
  end
  #permissions
	def self.search_secure user, base_object
    base_object.where(search_where(user))
  end
  def self.search_where user
    "1=1" #no security yet
  end
end
