require 'spec_helper'

describe OpenChain::EntityCompare::CascadeProductValidations do
  context :orders do
    it "should call BusinessValidationTemplate.create_results_for_object! for linked orders" do
      p = Factory(:product)
      ol = Factory(:order_line,product:p)
      ol_duplicate = Factory(:order_line,product:p,order:ol.order)
      ol2 = Factory(:order_line,product:p)
      ol_ignore = Factory(:order_line)

      expect(BusinessValidationTemplate).to receive(:create_results_for_object!).with ol.order
      expect(BusinessValidationTemplate).to receive(:create_results_for_object!).with ol2.order

      described_class.compare 'Product', p.id, nil, nil, nil, nil, nil, nil
    end
    it "should ignore non-products" do
      o = Factory(:order)

      expect(BusinessValidationTemplate).not_to receive(:create_results_for_object!)

      described_class.compare 'Order', o.id, nil, nil, nil, nil, nil, nil
    end
  end
  context :shipments do
    it "should call BusinessValidationTemplate.create_results_for_object! for linked shipments" do
      p = Factory(:product)
      l = Factory(:shipment_line,product:p)
      l_duplicate = Factory(:shipment_line,product:p,shipment:l.shipment)
      l2 = Factory(:shipment_line,product:p)
      l_ignore = Factory(:shipment_line)

      expect(BusinessValidationTemplate).to receive(:create_results_for_object!).with l.shipment
      expect(BusinessValidationTemplate).to receive(:create_results_for_object!).with l2.shipment

      described_class.compare 'Product', p.id, nil, nil, nil, nil, nil, nil
    end
    it "should ignore non-products" do
      s = Factory(:shipment)

      expect(BusinessValidationTemplate).not_to receive(:create_results_for_object!)

      described_class.compare 'Shipment', s.id, nil, nil, nil, nil, nil, nil
    end
  end 
end