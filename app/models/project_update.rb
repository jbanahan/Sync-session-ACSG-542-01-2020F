# == Schema Information
#
# Table name: project_updates
#
#  id            :integer          not null, primary key
#  project_id    :integer
#  created_by_id :integer
#  body          :text
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_project_updates_on_created_by_id  (created_by_id)
#  index_project_updates_on_project_id     (project_id)
#

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
