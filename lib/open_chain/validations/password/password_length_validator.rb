module OpenChain; module Validations; module Password; class PasswordLengthValidator
  def self.valid_password?(user, password)
    if password.length >= 8
      true
    else
      user.errors.add(:password, 'must be at least 8 characters long')
      false
    end
  end
end; end; end; end