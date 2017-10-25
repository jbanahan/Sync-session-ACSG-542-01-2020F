require 'open_chain/entity_compare/comparator_registry'
require 'open_chain/entity_compare/entity_comparator'
require 'open_chain/entity_compare/run_business_validations'
require 'open_chain/custom_handler/lumber_liquidators/lumber_order_change_comparator'
require 'open_chain/custom_handler/lumber_liquidators/lumber_product_vendor_assignment_change_comparator'
require 'open_chain/entity_compare/business_rule_comparator/business_rule_notification_comparator'

if !Rails.env.test? && ActiveRecord::Base.connection.table_exists?('master_setups')

  # Setup the comparator registry
  comparators_to_register = [OpenChain::EntityCompare::BusinessRuleComparator::BusinessRuleNotificationComparator]

  if Rails.env.to_sym==:production
    comparators_to_register << OpenChain::EntityCompare::RunBusinessValidations
  end

  comparators_to_register.each {|c| OpenChain::EntityCompare::ComparatorRegistry.register c}
end
