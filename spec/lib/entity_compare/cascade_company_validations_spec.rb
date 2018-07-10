describe OpenChain::EntityCompare::CascadeCompanyValidations do

  subject { described_class }

  describe "compare" do
    it "should ignore non-companies" do
      expect(BusinessValidationTemplate).not_to receive(:create_results_for_object!)
      subject.compare 'Order', Factory(:order).id, nil, nil, nil, nil, nil, nil
    end

    it "ignores updates to the master company" do
      expect(subject).not_to receive(:validate_connected_orders)
      expect(subject).not_to receive(:validate_connected_entries)

      subject.compare 'Company', Factory(:master_company).id, nil, nil, nil, nil, nil, nil
    end

    context "orders" do
      let (:vendor) { Factory(:company, vendor: true) }
      let (:order) { Factory(:order, vendor: vendor) }

      it "should call BusinessValidationTemplate.create_results_for_object! for orders where company is vendor" do
        expect(BusinessValidationTemplate).to receive(:create_results_for_object!).with(order)
        subject.compare 'Company', vendor.id, nil, nil, nil, nil, nil, nil
      end

      it "should call BusinessValidationTemplate.create_results_for_object! for orders where company is importer" do
        order.update_attributes! vendor_id: nil, importer_id: vendor.id
        expect(BusinessValidationTemplate).to receive(:create_results_for_object!).with(order)
        subject.compare 'Company', vendor.id, nil, nil, nil, nil, nil, nil
      end

      it "does not validate cancelled orders" do
        order.update_attributes! closed_at: Time.zone.now
        expect(BusinessValidationTemplate).not_to receive(:create_results_for_object!)
        subject.compare 'Company', vendor.id, nil, nil, nil, nil, nil, nil
      end

      it "does not validate if master setup option is enabled" do
        ms = stub_master_setup
        expect(ms).to receive(:custom_feature?).with("Disable Cascading Company to Order Validations").and_return true
        expect(BusinessValidationTemplate).not_to receive(:create_results_for_object!)
        subject.compare 'Company', vendor.id, nil, nil, nil, nil, nil, nil
      end
    end

    context "entries" do
      let (:importer) { Factory(:importer) }
      let (:entry) { Factory(:entry, importer: importer) }

      it "should call BusinessValidationTemplate.create_results_for_object! for entries where company is importer" do
        expect(BusinessValidationTemplate).to receive(:create_results_for_object!).with(entry)
        subject.compare 'Company', importer.id, nil, nil, nil, nil, nil, nil
      end

      it "does not validate entries if master setup option is disabled" do
        ms = stub_master_setup
        expect(ms).to receive(:custom_feature?).with("Disable Cascading Company to Entry Validations").and_return true
        expect(BusinessValidationTemplate).not_to receive(:create_results_for_object!)
        subject.compare 'Company', importer.id, nil, nil, nil, nil, nil, nil
      end
    end 
  end
end