class RunAsSession < ActiveRecord::Base
  has_many :request_logs, dependent: :destroy, inverse_of: :run_as_session
  belongs_to :user
  belongs_to :run_as_user, class_name: "User"

  scope :current_session, lambda {|user| where(user_id: user.id, end_time: nil)}
end