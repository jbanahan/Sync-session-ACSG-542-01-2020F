require 'spec_helper'

describe OpenChain::EntityCompare::CascadeCompanyValidations do
  it "should ignore non-companies" do
    o = Factory(:order)

    BusinessValidationTemplate.should_not_receive(:create_results_for_object!)

    described_class.compare 'Order', o.id, nil, nil, nil, nil, nil, nil
  end
  context :orders do
    it "should call BusinessValidationTemplate.create_results_for_object! for orders where company is vendor" do
      c = Factory(:company,vendor:true)
      o = Factory(:order,vendor:c)

      BusinessValidationTemplate.should_receive(:create_results_for_object!).with(o)

      described_class.compare 'Company', c.id, nil, nil, nil, nil, nil, nil 

    end
    it "should call BusinessValidationTemplate.create_results_for_object! for orders where company is importer" do
      c = Factory(:company)
      o = Factory(:order,importer:c)

      BusinessValidationTemplate.should_receive(:create_results_for_object!).with(o)

      described_class.compare 'Company', c.id, nil, nil, nil, nil, nil, nil       
    end
  end
  context :entries do
    it "should call BusinessValidationTemplate.create_results_for_object! for entries where company is importer" do
      c = Factory(:company)
      ent = Factory(:entry,importer:c)

      BusinessValidationTemplate.should_receive(:create_results_for_object!).with(ent)

      described_class.compare 'Company', c.id, nil, nil, nil, nil, nil, nil       
    end
  end 
end