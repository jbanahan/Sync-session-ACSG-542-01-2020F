class DashboardWidget < ActiveRecord::Base

  belongs_to :search_setup
  belongs_to :user

  validates :user, :presence=>true

  default_scope order("rank ASC")
end
