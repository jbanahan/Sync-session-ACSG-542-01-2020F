module OpenChain; module UserSupport; class FailedPasswordHandler
  def self.call(user)
    user.failed_logins = user.failed_logins.to_i + 1
    user.password_locked = true if user.failed_logins >= 5

    user.save!
    nil
  end
end; end; end