module PasswordResetsHelper
  def requires_old_password?(user=nil)
    false if user.blank?
    user.confirmation_token.blank? && (user.password_expired && !user.password_locked)
  end
end