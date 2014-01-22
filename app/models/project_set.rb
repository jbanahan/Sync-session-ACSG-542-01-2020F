class ProjectSet < ActiveRecord::Base
  attr_accessible :name
  has_and_belongs_to_many :projects

  validates :name, uniqueness: true
end
