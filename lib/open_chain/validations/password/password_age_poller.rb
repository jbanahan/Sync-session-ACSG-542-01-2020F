module OpenChain; module Validations; module Password; class PasswordAgePoller
  def self.run_schedulable opts = {}
    expired_days = opts['password_age_limit']

    self.new.run(expired_days)
  end

  def run(expired_days)
    expired = expired_passwords(expired_days)
    expired.each do |user|
      user.password_expired = true
      user.password_reset = true
      user.save!
      user.create_snapshot(User.integration, nil, "Password Past Maximum Age")
    end
  end

  def expired_passwords(expiration_days)
    User.where("password_changed_at <= ? AND (system_user is NULL OR system_user=0)", expiration_days.to_i.days.ago)
  end
end; end; end; end