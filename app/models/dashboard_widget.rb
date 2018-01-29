# == Schema Information
#
# Table name: dashboard_widgets
#
#  id              :integer          not null, primary key
#  user_id         :integer
#  search_setup_id :integer
#  rank            :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_dashboard_widgets_on_user_id  (user_id)
#

class DashboardWidget < ActiveRecord::Base

  belongs_to :search_setup
  belongs_to :user

  validates :user, :presence=>true

  default_scope order("rank ASC")
end
