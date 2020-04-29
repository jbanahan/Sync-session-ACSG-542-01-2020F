require 'open_chain/service_locator'
require 'open_chain/registries/registry_support'

module OpenChain; module AntiVirus; class AntiVirusRegistry
  extend OpenChain::ServiceLocator
  extend OpenChain::Registries::RegistrySupport

  def self.check_validity reg_class
    check_registration_validity(reg_class, "AntiVirusScanner", [:safe?])
  end

  def self.safe? file
    evaluate_registered_permission(:safe?, file)
  end
end; end; end