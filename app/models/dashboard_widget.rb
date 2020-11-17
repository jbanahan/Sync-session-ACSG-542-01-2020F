# == Schema Information
#
# Table name: dashboard_widgets
#
#  created_at      :datetime         not null
#  id              :integer          not null, primary key
#  rank            :integer
#  search_setup_id :integer
#  updated_at      :datetime         not null
#  user_id         :integer
#
# Indexes
#
#  index_dashboard_widgets_on_user_id  (user_id)
#

class DashboardWidget < ActiveRecord::Base
  belongs_to :search_setup
  belongs_to :user

  validates :user, :presence=>true

  scope :by_rank, -> { order(:rank) }
end
