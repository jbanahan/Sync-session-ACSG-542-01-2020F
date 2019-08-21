module OpenChain; module Validations; module Password; class PreviousPasswordValidator
  def self.valid_password?(user, password)
    used_password = false

    user.recent_password_hashes(password_history_length).each do |old_password|
      crypted_password = user.encrypt_password(old_password.password_salt, password)
      used_password = true if crypted_password == old_password.hashed_password
    end

    user.errors.add(:password, "cannot be the same as the last #{password_history_length} passwords")
    !used_password
  end

  def self.password_history_length
    24
  end
end; end; end; end