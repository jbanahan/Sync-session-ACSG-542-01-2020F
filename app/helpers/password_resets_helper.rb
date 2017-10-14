module PasswordResetsHelper
  def requires_old_password?(user=nil)
    false if user.blank?
    user.forgot_password.blank? && (user.password_expired && !user.password_locked)
  end
end