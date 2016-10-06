require 'spec_helper'

describe ModuleChain do
  describe "model_fields" do
    it "returns all model fields for the chain" do
      subject.add_array([CoreModule::PRODUCT,CoreModule::CLASSIFICATION,CoreModule::TARIFF])

      # first, confirm that the setup for Product includes children outside the chain
      expect(CoreModule::PRODUCT.model_fields_including_children.values.find { |mf| mf.core_module==CoreModule::VARIANT}).to_not be_nil

      product_fields = CoreModule::PRODUCT.model_fields.keys
      classification_fields = CoreModule::CLASSIFICATION.model_fields.keys
      tariff_fields = CoreModule::TARIFF.model_fields.keys

      expected_fields = product_fields+classification_fields+tariff_fields

      expect(subject.model_fields.keys).to eq expected_fields
    end
  end

  describe "add" do
    it "adds a SiblingModule to the chain" do
      subject.add CoreModule::SHIPMENT
      subject.add ModuleChain::SiblingModules.new(CoreModule::SHIPMENT_LINE, CoreModule::BOOKING_LINE)

      expect(subject.to_a).to eq [CoreModule::SHIPMENT, CoreModule::SHIPMENT_LINE, CoreModule::BOOKING_LINE]
    end

    it "raises an error if sibling module is used first" do
      expect {subject.add ModuleChain::SiblingModules.new(CoreModule::SHIPMENT_LINE, CoreModule::BOOKING_LINE)}.to raise_error "SiblingModules cannot be used at the top of a ModuleChain"
    end

    it "raises an error if sibling module is not at bottom of chain" do
      subject.add CoreModule::SHIPMENT
      subject.add ModuleChain::SiblingModules.new(CoreModule::SHIPMENT_LINE, CoreModule::BOOKING_LINE)

      expect {subject.add CoreModule::SHIPMENT}.to raise_error "You cannot add modules to a chain that already contains a SiblingModule. SiblingModules must be at the bottom of the chain."
    end
  end

  describe "child_modules" do
    it "returns all child modules" do
      subject.add CoreModule::ENTRY
      subject.add CoreModule::COMMERCIAL_INVOICE
      subject.add CoreModule::COMMERCIAL_INVOICE_LINE

      expect(subject.child_modules(CoreModule::ENTRY)).to eq [CoreModule::COMMERCIAL_INVOICE, CoreModule::COMMERCIAL_INVOICE_LINE]
    end

    it "handles SiblingModules" do
      subject.add CoreModule::ENTRY
      subject.add CoreModule::COMMERCIAL_INVOICE
      subject.add ModuleChain::SiblingModules.new(CoreModule::COMMERCIAL_INVOICE_LINE, CoreModule::COMMERCIAL_INVOICE_TARIFF)

      expect(subject.child_modules(CoreModule::ENTRY)).to eq [CoreModule::COMMERCIAL_INVOICE, CoreModule::COMMERCIAL_INVOICE_LINE, CoreModule::COMMERCIAL_INVOICE_TARIFF]
    end
  end

  describe "first" do
    it "returns the first core module in the chain" do
      subject.add CoreModule::ENTRY
      subject.add CoreModule::COMMERCIAL_INVOICE

      expect(subject.first).to eq CoreModule::ENTRY
    end
  end

  describe "top?" do
    it "returns true if module is first in the list" do
      subject.add CoreModule::ENTRY
      subject.add CoreModule::COMMERCIAL_INVOICE

      expect(subject.top? CoreModule::ENTRY).to eq true
      expect(subject.top? CoreModule::COMMERCIAL_INVOICE).to eq false
    end
  end

  describe "child" do
    it "returns an array of direct child modules" do
      subject.add CoreModule::ENTRY
      subject.add CoreModule::COMMERCIAL_INVOICE
      subject.add CoreModule::COMMERCIAL_INVOICE_LINE

      expect(subject.child CoreModule::ENTRY).to eq [CoreModule::COMMERCIAL_INVOICE]
    end

    it "handles sibling modules" do
      subject.add CoreModule::SHIPMENT
      subject.add ModuleChain::SiblingModules.new(CoreModule::SHIPMENT_LINE, CoreModule::BOOKING_LINE)

      expect(subject.child CoreModule::SHIPMENT).to eq [CoreModule::SHIPMENT_LINE, CoreModule::BOOKING_LINE]
    end

    it "returns nil if if no more child modules exist" do
      subject.add CoreModule::ENTRY
      subject.add CoreModule::COMMERCIAL_INVOICE
      subject.add CoreModule::COMMERCIAL_INVOICE_LINE

      expect(subject.child CoreModule::COMMERCIAL_INVOICE_LINE).to be_nil
    end

    it "returns nil if referenced module is in a sibling module" do
      subject.add CoreModule::SHIPMENT
      subject.add ModuleChain::SiblingModules.new(CoreModule::SHIPMENT_LINE, CoreModule::BOOKING_LINE)

      expect(subject.child CoreModule::SHIPMENT_LINE).to be_nil
    end
  end
end