require 'open_chain/service_locator'
require 'open_chain/registries/registry_support'

module OpenChain; module Registries; class PasswordValidationRegistry
  extend OpenChain::ServiceLocator
  extend OpenChain::Registries::RegistrySupport

  def self.check_validity reg_class
    check_registration_validity(reg_class, "PasswordValidation", [:valid_password?])
  end

  def self.valid_password? user, password
    evaluate_registered_permission(:valid_password?, user, password)
  end

end; end; end