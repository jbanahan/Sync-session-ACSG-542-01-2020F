require 'open_chain/service_locator'
module OpenChain; class PasswordValidationRegistry
  extend OpenChain::ServiceLocator

  def self.check_validity reg_class
    return true if reg_class.respond_to?(:valid_password?)
    raise "PasswordValidation Class must implement valid_password?"
  end

  def self.registered_for_valid_password
    registered.find_all { |c| c.respond_to?(:valid_password?) }
  end
end; end