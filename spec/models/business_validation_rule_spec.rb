require 'spec_helper'

describe BusinessValidationRule do
  it "should default should_skip? to false" do
    bvr = BusinessValidationRule.new
    expect(bvr.should_skip?(Order.new)).to be_false
  end
end
