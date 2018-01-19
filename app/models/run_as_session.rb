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