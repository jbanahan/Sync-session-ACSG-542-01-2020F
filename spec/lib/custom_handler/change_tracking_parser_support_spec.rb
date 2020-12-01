describe OpenChain::CustomHandler::ChangeTrackingParserSupport do
  subject do
    Class.new do
      include OpenChain::CustomHandler::ChangeTrackingParserSupport
      include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

      def cdefs
        @cdefs ||= self.class.prep_custom_definitions([:prod_part_number])
      end

    end.new
  end

  describe "set_custom_value" do
    let (:object) { FactoryBot(:product) }
    let (:changed) { MutableBoolean.new false }

    it "updates custom value" do
      expect(subject.set_custom_value(object, :prod_part_number, changed, "TEST")).to eq true
      expect(object.custom_value(subject.cdefs[:prod_part_number])).to eq "TEST"
      expect(changed.value).to eq true
    end

    it "does not update existing values" do
      object.update_custom_value!(subject.cdefs[:prod_part_number], "TEST")
      expect(subject.set_custom_value(object, :prod_part_number, changed, "TEST")).to eq false
      expect(changed.value).to eq false
    end

    it "handles nil when custom value doesn't exist yet" do
      expect(subject.set_custom_value(object, :prod_part_number, changed, nil)).to eq false
      # Make sure it didn't add a custom value to obj
      expect(object.custom_values.length).to eq 0
    end

    it "handles nil value when custom value exists" do
      object.update_custom_value!(subject.cdefs[:prod_part_number], "TEST")
      expect(subject.set_custom_value(object, :prod_part_number, changed, nil)).to eq true
      expect(changed.value).to eq true
    end
  end

  describe "remove_custom_value" do
    let (:object) { FactoryBot(:product) }
    let (:changed) { MutableBoolean.new false }

    it "removes custom value value" do
      object.update_custom_value!(subject.cdefs[:prod_part_number], "TEST")
      expect(subject.remove_custom_value(object, :prod_part_number, changed)).to eq true
      expect(changed.value).to eq true
    end

    it "no-ops if value is already blank" do
      object.update_custom_value!(subject.cdefs[:prod_part_number], nil)
      expect(subject.remove_custom_value(object, :prod_part_number, changed)).to eq false
      expect(changed.value).to eq false
    end

    it "does not create a custom value object if one does not already exist" do
      expect(subject.remove_custom_value(object, :prod_part_number, changed)).to eq false
      expect(changed.value).to eq false
      expect(object.custom_values.length).to eq 0
    end
  end

  describe "set_value" do
    let (:object) { Product.new }
    let (:changed) { MutableBoolean.new false }

    it "updates an attribute" do
      expect(subject.set_value(object, :unique_identifier, changed, "TEST")).to eq true
      expect(changed.value).to eq true
      expect(object.unique_identifier).to eq "TEST"
    end

    it "recognizes if attribute does not change" do
      object.update! unique_identifier: 'TEST'
      expect(subject.set_value(object, :unique_identifier, changed, "TEST")).to eq false
      expect(changed.value).to eq false
      expect(object.unique_identifier).to eq "TEST"
    end

    it "recognizes if attribute is blanked" do
      object.update! unique_identifier: 'TEST'
      expect(subject.set_value(object, :unique_identifier, changed, nil)).to eq true
      expect(changed.value).to eq true
      expect(object.unique_identifier).to eq nil
    end
  end
end