module OpenChain; module UserSupport; class FailedPasswordHandler
  def self.call(user)
    failed_logins = user.failed_logins + 1
    user.update_attribute(:failed_logins, failed_logins)
    user.update_attribute(:password_locked, true) if failed_logins >= 5
  end
end; end; end