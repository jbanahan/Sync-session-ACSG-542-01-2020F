module OpenChain; class InactiveAccountChecker
  def self.run_schedulable(opts={})
    self.new.run
  end

  def run
    inactive_users = User.where("system_user != true OR system_user IS NULL").where('last_request_at <= ?', 90.days.ago)
    inactive_users.update_all(password_locked: true)
  end
end; end