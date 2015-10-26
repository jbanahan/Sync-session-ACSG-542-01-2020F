require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberValidationRuleOrderCascadingRisk do
  before :each do
    @cdefs = described_class.prep_custom_definitions [:cmp_risk, :prod_risk, :ord_risk]
  end
  it "should fail if product is higher risk than order" do
    p = Factory(:product)
    p.update_custom_value!(@cdefs[:prod_risk],'High')
    ol = Factory(:order_line,product:p)
    ol.order.update_custom_value!(@cdefs[:ord_risk],'Low')
    expect(described_class.new.run_validation(ol.order)).to_not be_nil
  end
  it "should fail if vendor is higher risk than order" do
    c = Factory(:company,vendor:true)
    c.update_custom_value!(@cdefs[:cmp_risk],'High')
    o = Factory(:order,vendor:c)
    o.update_custom_value!(@cdefs[:ord_risk],'Low')
    expect(described_class.new.run_validation(o)).to_not be_nil
  end
  it "should fail if product risk not set" do
    p = Factory(:product)
    ol = Factory(:order_line,product:p)
    ol.order.update_custom_value!(@cdefs[:ord_risk],'Low')
    expect(described_class.new.run_validation(ol.order)).to_not be_nil
  end
  it "should fail if vendor risk not set" do
    c = Factory(:company,vendor:true)
    o = Factory(:order,vendor:c)
    o.update_custom_value!(@cdefs[:ord_risk],'Low')
    expect(described_class.new.run_validation(o)).to_not be_nil
  end
  it "should pass if products and vendor are equal risk to order" do
    c = Factory(:company,vendor:true)
    c.update_custom_value!(@cdefs[:cmp_risk],'High')
    o = Factory(:order,vendor:c)
    o.update_custom_value!(@cdefs[:ord_risk],'High')
    p = Factory(:product)
    p.update_custom_value!(@cdefs[:prod_risk],'High')
    ol = Factory(:order_line,product:p,order:o)

    expect(described_class.new.run_validation(o)).to be_nil
  end
  it "should pass if products and vendor are lower risk than order" do
    c = Factory(:company,vendor:true)
    c.update_custom_value!(@cdefs[:cmp_risk],'Low')
    o = Factory(:order,vendor:c)
    o.update_custom_value!(@cdefs[:ord_risk],'High')
    p = Factory(:product)
    p.update_custom_value!(@cdefs[:prod_risk],'Low')
    ol = Factory(:order_line,product:p,order:o)

    expect(described_class.new.run_validation(o)).to be_nil
  end
  it "should skip if order risk not set" do
    o = Factory(:order)
    expect(described_class.new.should_skip?(o)).to be_true
  end
  it "should skip if order is Grandfathered" do
    o = Factory(:order)
    o.update_custom_value!(@cdefs[:ord_risk],'Grandfathered')
    expect(described_class.new.should_skip?(o)).to be_true
  end
  it "should not skip if order risk is set" do
    o = Factory(:order)
    o.update_custom_value!(@cdefs[:ord_risk],'Low')
    expect(described_class.new.should_skip?(o)).to be_false
  end
end