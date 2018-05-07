require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberOrderAcceptance
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport

  def self.can_accept? order, user
    return user.admin? ||
      (
        (user.company == order.vendor || user.company == order.agent)  &&
        user.in_group?('ORDERACCEPT')
      )
  end

  def self.can_be_accepted? ord
    return false if ord.fob_point.blank?
    return false if ord.terms_of_sale.blank?
    cdefs = prep_custom_definitions([:ord_country_of_origin])
    return false if ord.get_custom_value(cdefs[:ord_country_of_origin]).value.blank?
    return true
  end
  
end; end; end; end
