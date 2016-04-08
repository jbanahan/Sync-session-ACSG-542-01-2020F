require 'open_chain/service_locator'
module OpenChain; class OrderAcceptanceRegistry
  extend OpenChain::ServiceLocator

  def self.check_validity reg_class
    return true if reg_class.respond_to?(:can_be_accepted?) || reg_class.respond_to?(:can_accept?)
    raise "OrderAcceptance Class must implement can_be_accepted? or can_accept?"
  end

  def self.registered_for_can_accept
    registered.find_all {|c| c.respond_to?(:can_accept?)}
  end

  def self.registered_for_can_be_accepted
    registered.find_all {|c| c.respond_to?(:can_be_accepted?)}
  end
end; end
