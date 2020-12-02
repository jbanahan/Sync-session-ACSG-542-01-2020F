describe OpenChain::CustomHandler::UnderArmour::UnderArmourBusinessLogic do

  let (:subject) do
    Class.new do
      include OpenChain::CustomHandler::UnderArmour::UnderArmourBusinessLogic
      include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
    end.new
  end

  describe "total_units_per_inner_pack" do
    let (:cdefs) do
      subject.class.prep_custom_definitions([:var_units_per_inner_pack])
    end

    it "sums variant units per inner pack" do
      p = create(:product)
      v = p.variants.create! variant_identifier: '1'
      v.update_custom_value! cdefs[:var_units_per_inner_pack], BigDecimal('2.51')
      v2 = p.variants.create! variant_identifier: '2'
      v2.update_custom_value! cdefs[:var_units_per_inner_pack], BigDecimal('1')
      v3 = p.variants.create! variant_identifier: '3'
      v3.update_custom_value! cdefs[:var_units_per_inner_pack], nil
      v4 = p.variants.create! variant_identifier: '4'
      v4.update_custom_value! cdefs[:var_units_per_inner_pack], BigDecimal('2')

      expect(subject.total_units_per_inner_pack(p)).to eq BigDecimal('5.51')
    end
  end

  describe "exploded_quantity" do
    it "uses prepack inner quantities to determine an exploded quantity" do
      p = create(:product)
      ship_line = create(:shipment_line, product: p, quantity: BigDecimal("2"))

      expect(subject).to receive(:total_units_per_inner_pack).with(p).and_return BigDecimal('5')

      expect(subject.exploded_quantity(ship_line)).to eq BigDecimal("10")
    end

    it "returns zero when shipment line quantity not set" do
      p = create(:product)
      ship_line = create(:shipment_line, product: p, quantity: nil)

      expect(subject).to receive(:total_units_per_inner_pack).with(p).and_return BigDecimal('5')

      expect(subject.exploded_quantity(ship_line)).to eq BigDecimal(0)
    end
  end
end