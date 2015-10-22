require 'spec_helper'

describe OpenChain::EntityCompare::RunBusinessValidations do
  it "should call BusinessValidationTemplate.create_results_for_object!" do
    @ord = Factory(:order)
    BusinessValidationTemplate.should_receive(:create_results_for_object!).with(instance_of(Order))
    described_class.compare 'Order', @ord.id, nil, nil, nil, nil, nil, nil
  end
end