class Project < ActiveRecord::Base
  attr_accessible :due, :name, :closed_at, :objective, :drive_folder
  
  has_many :project_updates, dependent: :destroy, inverse_of: :project
  has_many :project_deliverables, dependent: :destroy, inverse_of: :project

  def red?
    !red_messages.blank?
  end

  # return array of issues that are causing the project to be red
  def red_messages
    return [] if self.closed_at #never red if closed
    r = []
    r << "Project is overdue." if self.due && self.due < 0.days.ago.to_date
    r << "Project hasn't been updated for more than 10 days." if self.updated_at && self.updated_at < 10.days.ago
    r
  end

  #permissions
	def self.search_secure user, base_object
    base_object.where(search_where(user))
  end
  def self.search_where user
    "1=1" #no security yet
  end
  def can_view? user
    user.view_projects?
  end
  def can_edit? user
    user.edit_projects?
  end
end
