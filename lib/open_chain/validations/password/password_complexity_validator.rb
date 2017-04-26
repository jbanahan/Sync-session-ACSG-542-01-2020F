module OpenChain; module Validations; module Password; class PasswordComplexityValidator
  def self.valid_password?(user, password)
    matches = []
    validation_methods = [:has_digit?, :has_lowercase?, :has_uppercase?, :has_symbol?]

    validation_methods.each do |method|
      matches << public_send(method, password)
    end

    if matches.reject { |match| match.blank? }.length >= 3
      true
    else
      user.errors.add(:password, 'must contain 3 of the 4 following characters: upper case letter, lower case letter, number, symbol')
      false
    end
  end

  def self.has_digit?(password)
    password.match(/[[:digit:]]/).present?
  end

  def self.has_lowercase?(password)
    password.match(/[[:lower:]]/).present?
  end

  def self.has_uppercase?(password)
    password.match(/[[:upper:]]/).present?
  end

  def self.has_symbol?(password)
    password.match(/[^[[:alnum:]]]/).present?
  end
end; end; end; end