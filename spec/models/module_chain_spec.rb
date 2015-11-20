require 'spec_helper'

describe ModuleChain do
  describe "#model_fields" do
    it "should return all model fields for the chain" do
      chain = described_class.new
      chain.add_array([CoreModule::PRODUCT,CoreModule::CLASSIFICATION,CoreModule::TARIFF])

      # first, confirm that the setup for Product includes children outside the chain
      expect(CoreModule::PRODUCT.model_fields_including_children.values.find { |mf| mf.core_module==CoreModule::VARIANT}).to_not be_nil

      product_fields = CoreModule::PRODUCT.model_fields.keys
      classification_fields = CoreModule::CLASSIFICATION.model_fields.keys
      tariff_fields = CoreModule::TARIFF.model_fields.keys

      expected_fields = product_fields+classification_fields+tariff_fields

      expect(chain.model_fields.keys).to eq expected_fields
    end
  end
end