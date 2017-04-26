module OpenChain; module Validations; module Password; class PreviousPasswordValidator
  def self.valid_password?(user, password)
    used_password = false

    user.recent_password_hashes.each do |old_password|
      crypted_password = user.encrypt_password(old_password.password_salt, password)
      used_password = true if crypted_password == old_password.hashed_password
    end

    user.errors.add(:password, 'cannot be the same as the last 5 passwords')
    !used_password
  end
end; end; end; end