require 'open_chain/entity_compare/comparator_registry'
require 'open_chain/entity_compare/run_business_validations'
require 'open_chain/custom_handler/lumber_liquidators/lumber_order_change_comparator'

if !Rails.env.test? && ActiveRecord::Base.connection.table_exists?('master_setups')

  # Setup the comparator registry 
  comparators_to_register = []

  if Rails.env.to_sym==:production
    comparators_to_register << OpenChain::EntityCompare::RunBusinessValidations
  end

  if MasterSetup.get.system_code == 'll'
    comparators_to_register << OpenChain::CustomHandler::LumberLiquidators::LumberOrderChangeComparator
  end

  comparators_to_register.each {|c| OpenChain::EntityCompare::ComparatorRegistry.register c}
end