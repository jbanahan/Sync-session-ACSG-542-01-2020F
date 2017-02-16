require 'spec_helper'

describe OpenChain::EntityCompare::RunBusinessValidations do
  it "should call BusinessValidationTemplate.create_results_for_object!" do
    @ord = Factory(:order)
    expect(OpenChain::EntityCompare::CascadeProductValidations).to receive(:compare).with('Order', @ord.id, 'a','b','c','d','e','f')
    expect(OpenChain::EntityCompare::CascadeCompanyValidations).to receive(:compare).with('Order', @ord.id, 'a','b','c','d','e','f')
    described_class.compare 'Order', @ord.id, 'a','b','c','d','e','f'
  end
end