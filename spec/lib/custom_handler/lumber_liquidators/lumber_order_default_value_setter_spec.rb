describe OpenChain::CustomHandler::LumberLiquidators::LumberOrderDefaultValueSetter do
  describe "set_defaults" do
    before :each do
      @cdefs = described_class.prep_custom_definitions([:cmp_default_inco_term, :cmp_default_handover_port, :cmp_default_country_of_origin, :ord_country_of_origin])
      @vendor = create(:company)
      @order = create(:order, vendor:@vendor)
    end
    context "country_of_origin" do
      it "should set default Country of Origin" do
        @vendor.update_custom_value!(@cdefs[:cmp_default_country_of_origin], 'CN')
        expect {described_class.set_defaults(@order)}.to change(EntitySnapshot, :count).from(0).to(1)
        expect(EntitySnapshot.first.context).to eq "System Job: Order Default Value Setter"
        @order.reload
        expect(@order.get_custom_value(@cdefs[:ord_country_of_origin]).value).to eq 'CN'
      end
      it "allows disabling snapshot even if order changed" do
        @vendor.update_custom_value!(@cdefs[:cmp_default_country_of_origin], 'CN')
        expect(@order).not_to receive(:create_snapshot)
        expect(described_class.set_defaults(@order, entity_snapshot: false)).to eq true
      end
      it "should not overwrite an existing country of origin" do
        @vendor.update_custom_value!(@cdefs[:cmp_default_country_of_origin], 'CN')
        @order.update_custom_value!(@cdefs[:ord_country_of_origin], 'IN')
        expect {described_class.set_defaults(@order)}.to_not change(EntitySnapshot, :count)
        @order.reload
        expect(@order.get_custom_value(@cdefs[:ord_country_of_origin]).value).to eq 'IN'
      end
    end
    context "ship_from" do
      it "should set the ship from if the vendor only has one shipping address" do
        a = create(:address, shipping:true, company:@vendor)
        @vendor.reload
        expect {described_class.set_defaults(@order)}.to change(EntitySnapshot, :count).from(0).to(1)
        expect(EntitySnapshot.first.context).to eq "System Job: Order Default Value Setter"
        @order.reload
        expect(@order.ship_from_id).to eq a.id
      end
      it "should not set the ship from if the vendor has multiple shipping addresses" do
        create(:address, shipping:true, company:@vendor)
        create(:address, shipping:true, company:@vendor)
        expect {described_class.set_defaults(@order)}.to_not change(EntitySnapshot, :count)
        @order.reload
        expect(@order.ship_from_id).to be_nil
      end
      it "should not fail if the vendor has no shipping addresses" do
        expect {described_class.set_defaults(@order)}.to_not change(EntitySnapshot, :count)
        @order.reload
        expect(@order.ship_from_id).to be_nil
      end
      it "should not overwrite an existing ship from" do
        a = create(:address, shipping:true, company:@vendor)
        @vendor.reload
        @order.update_attributes(ship_from_id: -2)

        expect {described_class.set_defaults(@order)}.to_not change(EntitySnapshot, :count)
        @order.reload
        expect(@order.ship_from_id).to eq -2
      end
    end
    it "should not fail if vendor is nil" do
      o = Order.new
      expect {described_class.set_defaults(o)}.to_not change(EntitySnapshot, :count)
      expect(o.id).to be_nil
    end
  end
end
