module OpenChain; class InactiveAccountChecker
  def self.run_schedulable(opts={})
    self.new.run
  end

  def run
    inactive_users = User.where("system_user != true OR system_user IS NULL").where('last_request_at <= ?', 90.days.ago)
    inactive_users.each do |user|
      user.update_attribute(:password_locked, true)
      user.create_snapshot(User.integration, nil, "Inactive User Account")
    end
  end
end; end