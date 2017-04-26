module OpenChain; module Validations; module Password; class UsernameNotPasswordValidator
  def self.valid_password?(user, password)
    if password != user.username
      true
    else
      user.errors.add(:password, 'cannot be the same as the username')
      false
    end
  end
end; end; end; end