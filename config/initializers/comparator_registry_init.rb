require 'open_chain/entity_compare/comparator_registry'
require 'open_chain/entity_compare/run_business_validations'
# Setup the comparator registry 
comparators_to_register = []

if Rails.env.to_sym==:production
  comparators_to_register << OpenChain::EntityCompare::RunBusinessValidations
end

comparators_to_register.each {|c| OpenChain::EntityCompare::ComparatorRegistry.register c}