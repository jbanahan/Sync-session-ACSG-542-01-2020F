describe OpenChain::EntityCompare::CascadeProductValidations do

  subject { described_class }

  describe "compare" do
    it "should ignore non-products" do
      expect(BusinessValidationTemplate).not_to receive(:create_results_for_object!)
      subject.compare 'Order', FactoryBot(:order).id, nil, nil, nil, nil, nil, nil
    end

    context "orders" do

      it "should call BusinessValidationTemplate.create_results_for_object! for linked orders" do
        p = FactoryBot(:product)
        ol = FactoryBot(:order_line, product:p)
        ol_duplicate = FactoryBot(:order_line, product:p, order:ol.order)
        ol2 = FactoryBot(:order_line, product:p)
        ol_ignore = FactoryBot(:order_line)

        expect(BusinessValidationTemplate).to receive(:create_results_for_object!).with ol.order
        expect(BusinessValidationTemplate).to receive(:create_results_for_object!).with ol2.order

        subject.compare 'Product', p.id, nil, nil, nil, nil, nil, nil
      end

      it "does not validate orders if master setup option is present" do
        ms = stub_master_setup
        expect(ms).to receive(:custom_feature?).with("Disable Cascading Product to Order Validations").and_return true
        expect(subject).not_to receive(:validate_connected_orders)
        subject.compare 'Product', FactoryBot(:product).id, nil, nil, nil, nil, nil, nil
      end

      it "does not validate closed orders" do
        p = FactoryBot(:product)
        ol = FactoryBot(:order_line, product:p)
        ol.order.update_attributes! closed_at: Time.zone.now

        expect(BusinessValidationTemplate).not_to receive(:create_results_for_object!)
        subject.compare 'Product', p.id, nil, nil, nil, nil, nil, nil
      end
    end

    context "shipments" do

      it "should call BusinessValidationTemplate.create_results_for_object! for linked shipments" do
        p = FactoryBot(:product)
        l = FactoryBot(:shipment_line, product:p)
        l_duplicate = FactoryBot(:shipment_line, product:p, shipment:l.shipment)
        l2 = FactoryBot(:shipment_line, product:p)
        l_ignore = FactoryBot(:shipment_line)

        expect(BusinessValidationTemplate).to receive(:create_results_for_object!).with l.shipment
        expect(BusinessValidationTemplate).to receive(:create_results_for_object!).with l2.shipment

        subject.compare 'Product', p.id, nil, nil, nil, nil, nil, nil
      end

      it "does not validate shipments if master setup option is present" do
        ms = stub_master_setup
        expect(ms).to receive(:custom_feature?).with("Disable Cascading Product to Shipment Validations").and_return true
        expect(subject).not_to receive(:validate_connected_shipments)
        subject.compare 'Product', FactoryBot(:product).id, nil, nil, nil, nil, nil, nil
      end

      it "does not validate canceled shipments" do
        p = FactoryBot(:product)
        l = FactoryBot(:shipment_line, product:p)
        l.shipment.update_attributes! canceled_date: Time.zone.now

        expect(BusinessValidationTemplate).not_to receive(:create_results_for_object!)
        subject.compare 'Product', p.id, nil, nil, nil, nil, nil, nil
      end
    end

  end
end