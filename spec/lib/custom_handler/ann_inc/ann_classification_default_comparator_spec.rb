describe OpenChain::CustomHandler::AnnInc::AnnClassificationDefaultComparator do
  subject { described_class }
  let (:ann) { FactoryBot(:importer, system_code: "ann") }
  let (:cdef) { subject.new.cdef }

  describe "compare" do
    let(:prod) { FactoryBot(:product) }

    let(:classi_1) { FactoryBot(:classification, product: prod) }

    let(:classi_2) do
      c = FactoryBot(:classification, product: prod)
      c.update_custom_value! cdef, ""
      c
    end

    let(:classi_3) do
      c = FactoryBot(:classification, product: prod)
      c.update_custom_value! cdef, "Multi"
      c
    end

    it "sets 'classification type' to 'Not Applicable' if it's blank, does nothing otherwise" do
      classi_1; classi_2; classi_3
      new_snap = JSON.parse CoreModule::PRODUCT.entity_json(prod)
      expect_any_instance_of(subject).to receive(:get_json_hash).and_return new_snap
      expect_any_instance_of(Product).to receive(:create_snapshot).with(User.integration, nil, "AnnClassificationDefaultComparator")

      subject.compare("Product", prod.id, nil, nil, nil, "new_bucket", "new_path", "new_version")

      expect(classi_1.reload.custom_value(cdef)).to eq "Not Applicable"
      expect(classi_2.reload.custom_value(cdef)).to eq "Not Applicable"
      expect(classi_3.reload.custom_value(cdef)).to eq "Multi"
    end

    it "doesn't snapshot product if no classifications have been updated" do
      classi_3
      new_snap = JSON.parse CoreModule::PRODUCT.entity_json(prod)
      expect_any_instance_of(subject).to receive(:get_json_hash).and_return new_snap
      expect_any_instance_of(Product).to_not receive(:create_snapshot)

      subject.compare("Product", prod.id, nil, nil, nil, "new_bucket", "new_path", "new_version")

      expect(classi_3.reload.custom_value(cdef)).to eq "Multi"
    end
  end
end
