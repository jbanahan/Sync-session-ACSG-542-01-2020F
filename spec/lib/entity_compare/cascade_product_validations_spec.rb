describe OpenChain::EntityCompare::CascadeProductValidations do

  subject { described_class }

  describe "compare" do
    it "should ignore non-products" do
      expect(BusinessValidationTemplate).not_to receive(:create_results_for_object!)
      subject.compare 'Order', create(:order).id, nil, nil, nil, nil, nil, nil
    end

    context "orders" do

      it "should call BusinessValidationTemplate.create_results_for_object! for linked orders" do
        p = create(:product)
        ol = create(:order_line, product:p)
        ol_duplicate = create(:order_line, product:p, order:ol.order)
        ol2 = create(:order_line, product:p)
        ol_ignore = create(:order_line)

        expect(BusinessValidationTemplate).to receive(:create_results_for_object!).with ol.order
        expect(BusinessValidationTemplate).to receive(:create_results_for_object!).with ol2.order

        subject.compare 'Product', p.id, nil, nil, nil, nil, nil, nil
      end

      it "does not validate orders if master setup option is present" do
        ms = stub_master_setup
        expect(ms).to receive(:custom_feature?).with("Disable Cascading Product to Order Validations").and_return true
        expect(subject).not_to receive(:validate_connected_orders)
        subject.compare 'Product', create(:product).id, nil, nil, nil, nil, nil, nil
      end

      it "does not validate closed orders" do
        p = create(:product)
        ol = create(:order_line, product:p)
        ol.order.update_attributes! closed_at: Time.zone.now

        expect(BusinessValidationTemplate).not_to receive(:create_results_for_object!)
        subject.compare 'Product', p.id, nil, nil, nil, nil, nil, nil
      end
    end

    context "shipments" do

      it "should call BusinessValidationTemplate.create_results_for_object! for linked shipments" do
        p = create(:product)
        l = create(:shipment_line, product:p)
        l_duplicate = create(:shipment_line, product:p, shipment:l.shipment)
        l2 = create(:shipment_line, product:p)
        l_ignore = create(:shipment_line)

        expect(BusinessValidationTemplate).to receive(:create_results_for_object!).with l.shipment
        expect(BusinessValidationTemplate).to receive(:create_results_for_object!).with l2.shipment

        subject.compare 'Product', p.id, nil, nil, nil, nil, nil, nil
      end

      it "does not validate shipments if master setup option is present" do
        ms = stub_master_setup
        expect(ms).to receive(:custom_feature?).with("Disable Cascading Product to Shipment Validations").and_return true
        expect(subject).not_to receive(:validate_connected_shipments)
        subject.compare 'Product', create(:product).id, nil, nil, nil, nil, nil, nil
      end

      it "does not validate canceled shipments" do
        p = create(:product)
        l = create(:shipment_line, product:p)
        l.shipment.update_attributes! canceled_date: Time.zone.now

        expect(BusinessValidationTemplate).not_to receive(:create_results_for_object!)
        subject.compare 'Product', p.id, nil, nil, nil, nil, nil, nil
      end
    end

  end
end