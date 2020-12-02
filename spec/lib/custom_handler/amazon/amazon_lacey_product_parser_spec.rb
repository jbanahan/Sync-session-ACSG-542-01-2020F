describe OpenChain::CustomHandler::Amazon::AmazonLaceyProductParser do

  let (:fda_file) { IO.read 'spec/fixtures/files/amazon_lacey_parts.csv' }
  let (:csv_data) { CSV.parse(fda_file) }

  describe "process_part_lines" do
    let (:user) { create(:user) }
    let! (:importer) {
      add_system_identifier(with_customs_management_id(create(:importer), "CMID"), "Amazon Reference", "X76YHUR3GKHXS")
    }
    let (:cdefs) { subject.cdefs }
    let (:inbound_file) { InboundFile.new }
    let (:csv_rows) { [csv_data[1]] }

    before :each do
      allow(subject).to receive(:inbound_file).and_return inbound_file
    end

    it "creates product and sets Lacey data" do
      expect { subject.process_part_lines(user, "US_PGA_ALG_data.csv", csv_rows) }.to change { Product.count }.from(0).to(1)

      p = Product.first
      expect(p.importer).to eq importer
      expect(p.unique_identifier).to eq "CMID-EL89890"
      expect(p.custom_value(cdefs[:prod_lacey_component_of_article])).to eq "Bentwood Seats Made of Oak"
      expect(p.custom_value(cdefs[:prod_lacey_genus_1])).to eq "Quercus"
      expect(p.custom_value(cdefs[:prod_lacey_species_1])).to eq "Rubra"
      expect(p.custom_value(cdefs[:prod_lacey_country_of_harvest])).to eq "CN"
      expect(p.custom_value(cdefs[:prod_lacey_quantity])).to eq BigDecimal("4.23")
      expect(p.custom_value(cdefs[:prod_lacey_quantity_uom])).to eq "m^3"
      expect(p.custom_value(cdefs[:prod_lacey_percent_recycled])).to eq BigDecimal("0.51")
      expect(p.custom_value(cdefs[:prod_lacey_preparer_name])).to eq "Johnny Q. Importer"
      expect(p.custom_value(cdefs[:prod_lacey_preparer_email])).to eq "Johnny.Q.Imported@email.com"
      expect(p.custom_value(cdefs[:prod_lacey_preparer_phone])).to eq "555-123-4567"

      expect(p.entity_snapshots.length).to eq 1

      s = p.entity_snapshots.first
      expect(s.context).to eq "US_PGA_ALG_data.csv"
      expect(s.user).to eq user
    end

    it "updates product and sets Lacey data" do
      p = create(:product, importer: importer, unique_identifier: "CMID-EL89890")

      expect { subject.process_part_lines(user, "US_PGA_ALG_data.csv", csv_rows) }.not_to change { Product.count }.from(1)
      p.reload

      expect(p.importer).to eq importer
      expect(p.unique_identifier).to eq "CMID-EL89890"
      expect(p.custom_value(cdefs[:prod_lacey_component_of_article])).to eq "Bentwood Seats Made of Oak"
      expect(p.custom_value(cdefs[:prod_lacey_genus_1])).to eq "Quercus"
      expect(p.custom_value(cdefs[:prod_lacey_species_1])).to eq "Rubra"
      expect(p.custom_value(cdefs[:prod_lacey_country_of_harvest])).to eq "CN"
      expect(p.custom_value(cdefs[:prod_lacey_quantity])).to eq BigDecimal("4.23")
      expect(p.custom_value(cdefs[:prod_lacey_quantity_uom])).to eq "m^3"
      expect(p.custom_value(cdefs[:prod_lacey_percent_recycled])).to eq BigDecimal("0.51")
      expect(p.custom_value(cdefs[:prod_lacey_preparer_name])).to eq "Johnny Q. Importer"
      expect(p.custom_value(cdefs[:prod_lacey_preparer_email])).to eq "Johnny.Q.Imported@email.com"
      expect(p.custom_value(cdefs[:prod_lacey_preparer_phone])).to eq "555-123-4567"

      expect(p.entity_snapshots.length).to eq 1

      s = p.entity_snapshots.first
      expect(s.context).to eq "US_PGA_ALG_data.csv"
      expect(s.user).to eq user
    end

    it "does not snapshot if nothing updates" do
      p = create(:product, importer: importer, unique_identifier: "CMID-EL89890")
      p.update_custom_value! cdefs[:prod_lacey_component_of_article], "Bentwood Seats Made of Oak"
      p.update_custom_value! cdefs[:prod_lacey_genus_1], "Quercus"
      p.update_custom_value! cdefs[:prod_lacey_species_1], "Rubra"
      p.update_custom_value! cdefs[:prod_lacey_country_of_harvest], "CN"
      p.update_custom_value! cdefs[:prod_lacey_quantity], BigDecimal("4.23")
      p.update_custom_value! cdefs[:prod_lacey_quantity_uom], "m^3"
      p.update_custom_value! cdefs[:prod_lacey_percent_recycled], BigDecimal("0.51")
      p.update_custom_value! cdefs[:prod_lacey_preparer_name], "Johnny Q. Importer"
      p.update_custom_value! cdefs[:prod_lacey_preparer_email], "Johnny.Q.Imported@email.com"
      p.update_custom_value! cdefs[:prod_lacey_preparer_phone], "555-123-4567"

      subject.process_part_lines(user, "US_PGA_ALG_data.csv", csv_rows)

      p.reload
      expect(p.entity_snapshots.length).to eq 0
    end
  end
end