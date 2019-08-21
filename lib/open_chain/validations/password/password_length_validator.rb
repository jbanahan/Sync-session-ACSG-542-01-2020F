module OpenChain; module Validations; module Password; class PasswordLengthValidator
  def self.valid_password?(user, password)
    req_length = required_password_length user
    if password.length >= req_length
      true
    else
      user.errors.add(:password, "must be at least #{req_length} characters long")
      false
    end
  end

  def self.required_password_length user
    user.admin? ? 16 : 8
  end
end; end; end; end