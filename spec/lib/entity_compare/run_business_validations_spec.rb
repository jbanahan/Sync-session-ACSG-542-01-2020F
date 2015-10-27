require 'spec_helper'

describe OpenChain::EntityCompare::RunBusinessValidations do
  it "should call BusinessValidationTemplate.create_results_for_object!" do
    @ord = Factory(:order)
    BusinessValidationTemplate.should_receive(:create_results_for_object!).with(instance_of(Order))
    OpenChain::EntityCompare::CascadeProductValidations.should_receive(:compare).with('Order', @ord.id, 'a','b','c','d','e','f')
    OpenChain::EntityCompare::CascadeCompanyValidations.should_receive(:compare).with('Order', @ord.id, 'a','b','c','d','e','f')
    described_class.compare 'Order', @ord.id, 'a','b','c','d','e','f'
  end
end