module OpenChain; module Validations; module Password; class PasswordAgePoller
  def self.run_schedulable opts = {}
    expired_days = opts['password_age_limit']

    self.new.run(expired_days)
  end

  def run(expired_days)
    expired = expired_passwords(expired_days)
    expired.update_all(password_expired: true, password_reset: true)
  end

  def expired_passwords(expiration_days)
    User.where("password_changed_at <= ?", expiration_days.to_i.days.ago)
  end
end; end; end; end