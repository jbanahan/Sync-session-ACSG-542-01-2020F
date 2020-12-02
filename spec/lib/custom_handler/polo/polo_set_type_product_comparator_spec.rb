describe OpenChain::CustomHandler::Polo::PoloSetTypeProductComparator do
  let(:prod) { create(:product) }

  describe "accept?" do
    let(:snap) { create(:entity_snapshot) }

    it "returns 'true' for products" do
      snap.update! recordable: prod
      expect(described_class.accept? snap).to eq true
    end

    it "returns 'false' otherwise" do
      snap.update! recordable: create(:entry)
      expect(described_class.accept? snap).to eq false
    end
  end

  describe "compare" do
    let(:cdef) { described_class.prep_custom_definitions([:set_type])[:set_type] }
    let(:class_1) do
      cl = create(:classification, product: prod, country: create(:country, iso_code: "US"))
      cl.update_custom_value! cdef, "RL"
      cl
    end
    let(:class_2) do
      cl = create(:classification, product: prod, country: create(:country, iso_code: "CA"), tariff_records: [create(:tariff_record, line_number: 1), create(:tariff_record, line_number: 2)])
      cl.update_custom_value! cdef, "CTS"
      cl
    end
    let(:class_3) { create(:classification, product: prod, country: create(:country, iso_code: "CN"), tariff_records: [create(:tariff_record, line_number: 1), create(:tariff_record, line_number: 2)]) }
    let(:class_4) do
      cl = create(:classification, product: prod, country: create(:country, iso_code: "PK"), tariff_records: [create(:tariff_record)])
      cl.update_custom_value! cdef, "CTS"
      cl
    end

    let(:snap) do
      JSON.parse CoreModule::PRODUCT.entity_json(prod)
    end

    before { class_1; class_2; class_3; class_4 }

    it "updates classification set types to match that of US classification if there are multiple tariffs" do
      expect_any_instance_of(described_class).to receive(:get_json_hash).with("new_bucket", "new_path", "new_version").and_return snap
      expect {
        described_class.compare "Product", prod.id, "old_bucket", "old_path", "old_version", "new_bucket", "new_path", "new_version"
      }.to change(EntitySnapshot, :count).from(0).to(1)
      es = EntitySnapshot.first
      expect(es.recordable).to eq prod
      expect(es.user).to eq User.integration
      expect(es.context).to eq "PoloSetTypeProductComparator"
      expect(class_2.reload.custom_value(cdef)).to eq "RL"
      expect(class_3.reload.custom_value(cdef)).to eq "RL"
      expect(class_4.reload.custom_value(cdef)).to eq "CTS"
    end

    it "does nothing if classifications already match" do
      class_2.update_custom_value! cdef, "RL"
      class_3.update_custom_value! cdef, "RL"
      class_4.update_custom_value! cdef, "RL"

      expect_any_instance_of(described_class).to receive(:get_json_hash).with("new_bucket", "new_path", "new_version").and_return snap
      described_class.compare "Product", prod.id, "old_bucket", "old_path", "old_version", "new_bucket", "new_path", "new_version"
      expect(EntitySnapshot.count).to eq 0
    end
  end

end
