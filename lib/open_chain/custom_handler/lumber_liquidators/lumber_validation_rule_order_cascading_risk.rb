require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'
module OpenChain; module CustomHandler; module LumberLiquidators; class LumberValidationRuleOrderCascadingRisk < ::BusinessValidationRule
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport  
  RISK_VALUES ||= {
    grandfathered: 0,
    low: 100,
    medium: 200,
    high: 300
  }

  def should_skip? order
    cdefs = self.class.prep_custom_definitions [:ord_risk]
    order_risk = order.get_custom_value(cdefs[:ord_risk]).value
    return true if order_risk.blank?
    return true if order_risk.downcase.to_sym == :grandfathered
    return super(order)
  end

  def run_validation order
    cdefs = self.class.prep_custom_definitions [:ord_risk,:cmp_risk,:prod_risk]
    order_risk = order.get_custom_value(cdefs[:ord_risk]).value
    return nil if order_risk.blank?

    order_risk_value = risk_value(order_risk)
    return "ERROR: undefined Order risk value #{order_risk}." if order_risk_value.nil?
    
    messages = Set.new
    evaluate_vendor_risk order, messages, cdefs, order_risk, order_risk_value
    evaluate_product_risk order, messages, cdefs, order_risk, order_risk_value
    return messages.empty? ? nil : messages.to_a.join("\n")
  end

  def evaluate_vendor_risk order, messages, cdefs, order_risk, order_risk_value
    v = order.vendor
    return if v.nil?
    vend_risk = v.get_custom_value(cdefs[:cmp_risk]).value
    if vend_risk.blank?
      messages << "Vendor #{v.name} risk value is blank."
      return
    end
    vend_risk_value = risk_value(vend_risk)
    if vend_risk_value.nil?
      messages << "ERROR: undefined Vendor risk value #{vend_risk}."
      return
    end
    
    if vend_risk_value > order_risk_value
      messages << "Vendor #{v.name} has a higher risk (#{vend_risk}) than this order (#{order_risk})."
    end
  end
  private :evaluate_vendor_risk

  def evaluate_product_risk order, messages, cdefs, order_risk, order_risk_value
    order.order_lines.each do |ol|
      p = ol.product
      prod_risk = p.get_custom_value(cdefs[:prod_risk]).value
      if prod_risk.blank?
        messages << "Product #{p.unique_identifier} risk value is blank."
        next
      end

      prod_risk_value = risk_value(prod_risk)
      if prod_risk_value.nil?
        messages << "ERROR: undefined Product risk value #{prod_risk}."
        next
      end

      if prod_risk_value > order_risk_value
        messages << "Product #{p.unique_identifier} has a higher risk (#{prod_risk}) than this order (#{order_risk})."
      end
    end
  end
  private :evaluate_product_risk

  def risk_value risk_text
    RISK_VALUES[risk_text.downcase.to_sym]
  end
  private :risk_value
end; end; end; end