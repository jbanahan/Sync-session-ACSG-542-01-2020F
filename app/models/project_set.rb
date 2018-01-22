# == Schema Information
#
# Table name: project_sets
#
#  id         :integer          not null, primary key
#  name       :string(255)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_project_sets_on_name  (name) UNIQUE
#

class ProjectSet < ActiveRecord::Base
  attr_accessible :name
  has_and_belongs_to_many :projects

  validates :name, uniqueness: true
end
