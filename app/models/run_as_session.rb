# == Schema Information
#
# Table name: run_as_sessions
#
#  id             :integer          not null, primary key
#  user_id        :integer
#  run_as_user_id :integer
#  start_time     :datetime
#  end_time       :datetime
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_run_as_sessions_on_run_as_user_id  (run_as_user_id)
#  index_run_as_sessions_on_start_time      (start_time)
#  index_run_as_sessions_on_user_id         (user_id)
#

class RunAsSession < ActiveRecord::Base
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
