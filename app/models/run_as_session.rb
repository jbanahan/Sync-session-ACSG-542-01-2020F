# == Schema Information
#
# Table name: run_as_sessions
#
#  created_at     :datetime         not null
#  end_time       :datetime
#  id             :integer          not null, primary key
#  run_as_user_id :integer
#  start_time     :datetime
#  updated_at     :datetime         not null
#  user_id        :integer
#
# Indexes
#
#  index_run_as_sessions_on_run_as_user_id  (run_as_user_id)
#  index_run_as_sessions_on_start_time      (start_time)
#  index_run_as_sessions_on_user_id         (user_id)
#

class RunAsSession < ActiveRecord::Base
  attr_accessible :end_time, :run_as_user_id, :start_time, :user_id
  
  has_many :request_logs, dependent: :destroy, inverse_of: :run_as_session
  belongs_to :user
  belongs_to :run_as_user, class_name: "User"

  scope :current_session, lambda {|user| where(user_id: user.id, end_time: nil)}

  def self.search_where user
    return "1=0" unless user.admin?

    return "1=1"
  end

  def can_view? user
    return user.admin?
  end
end
