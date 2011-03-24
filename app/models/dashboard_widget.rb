class DashboardWidget < ActiveRecord::Base

  belongs_to :search_setup
  belongs_to :user

  validates :user, :presence=>true

end
