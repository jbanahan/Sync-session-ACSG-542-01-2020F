class ProjectUpdate < ActiveRecord::Base
  belongs_to :project, inverse_of: :project_updates, touch: true
  belongs_to :created_by, class_name:'User'
  attr_accessible :body

  def can_view? u
    self.project.can_view? u
  end

  def can_edit? u
    self.project.can_edit? u
  end
end
