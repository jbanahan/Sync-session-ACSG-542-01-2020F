describe OpenChain::CustomHandler::Amazon::AmazonFdaRadProductParser do

  let (:fda_file) { IO.read 'spec/fixtures/files/amazon_fda_rad_parts.csv' }
  let (:csv_data) { CSV.parse(fda_file) }

  describe "process_part_lines" do
    let (:user) { FactoryBot(:user) }
    let! (:importer) {
      add_system_identifier(with_customs_management_id(FactoryBot(:importer), "CMID"), "Amazon Reference", "X76YHUR3GKHXS")
    }
    let (:cdefs) { subject.cdefs }
    let (:inbound_file) { InboundFile.new }
    let (:csv_rows) { [csv_data[1]] }
    let! (:ra1) {
      # Make the description slightly off what's in the file so that we're making sure we're using fuzzy matches
      DataCrossReference.create! cross_reference_type: DataCrossReference::ACE_RADIATION_DECLARATION, value: "RA1",
        key: "WE DECLARE THAT THE PRODUCTS ARE NOT SUBJECT TO RADIATION PERFORMANCE STANDARDS BECAUSE THEY WERE MANUFACTURED PRIOR TO THE EFFECTIVE DATE OF ANY APPLICABLE STANDARD"
    }

    before :each do
      allow(subject).to receive(:inbound_file).and_return inbound_file
    end

    it "creates product and sets FDA RAD data" do
      expect { subject.process_part_lines(user, "US_PGA_RAD_data.csv", csv_rows) }.to change { Product.count }.from(0).to(1)

      p = Product.first
      expect(p.importer).to eq importer
      expect(p.unique_identifier).to eq "CMID-EL89890"
      expect(p.custom_value(cdefs[:prod_fda_model_number])).to eq "31202"
      expect(p.custom_value(cdefs[:prod_fda_brand_name])).to eq "CompuHyper Global"
      expect(p.custom_value(cdefs[:prod_fda_product_code])).to eq "RDH"
      expect(p.custom_value(cdefs[:prod_fda_contact_name])).to eq "John Allen"
      expect(p.custom_value(cdefs[:prod_fda_contact_title])).to eq "Customer Representative"
      expect(p.custom_value(cdefs[:prod_fda_container_type])).to eq "Box"
      expect(p.custom_value(cdefs[:prod_fda_items_per_inner_container])).to eq 100
      expect(p.custom_value(cdefs[:prod_fda_manufacture_date])).to eq Date.new(2018, 2, 12)
      expect(p.custom_value(cdefs[:prod_fda_exclusion_reason])).to eq "JUST BECAUSE"
      expect(p.custom_value(cdefs[:prod_fda_unknown_reason])).to eq "NOT SURE"
      expect(p.custom_value(cdefs[:prod_fda_accession_number])).to eq "1234567890"
      expect(p.custom_value(cdefs[:prod_fda_manufacturer_name])).to eq "Some Manufacturer"
      expect(p.custom_value(cdefs[:prod_fda_warning_accepted])).to eq true

      # This is testing that the right radiation code was used and the correct qualifier is set from that
      expect(p.custom_value(cdefs[:prod_fda_affirmation_compliance])).to eq "RA1"
      expect(p.custom_value(cdefs[:prod_fda_affirmation_compliance_value])).to eq "Feb 12, 2018"

      expect(p.entity_snapshots.length).to eq 1

      s = p.entity_snapshots.first
      expect(s.context).to eq "US_PGA_RAD_data.csv"
      expect(s.user).to eq user
    end

    it "updates FDA data" do
      p = FactoryBot(:product, importer: importer, unique_identifier: "CMID-EL89890")

      expect { subject.process_part_lines(user, "US_PGA_FDG_date.csv", csv_rows) }.not_to change { Product.count }.from(1)
      p.reload

      expect(p.importer).to eq importer
      expect(p.unique_identifier).to eq "CMID-EL89890"
      expect(p.custom_value(cdefs[:prod_fda_model_number])).to eq "31202"
      expect(p.custom_value(cdefs[:prod_fda_brand_name])).to eq "CompuHyper Global"
      expect(p.custom_value(cdefs[:prod_fda_product_code])).to eq "RDH"
      expect(p.custom_value(cdefs[:prod_fda_contact_name])).to eq "John Allen"
      expect(p.custom_value(cdefs[:prod_fda_contact_title])).to eq "Customer Representative"
      expect(p.custom_value(cdefs[:prod_fda_container_type])).to eq "Box"
      expect(p.custom_value(cdefs[:prod_fda_items_per_inner_container])).to eq 100
      expect(p.custom_value(cdefs[:prod_fda_manufacture_date])).to eq Date.new(2018, 2, 12)
      expect(p.custom_value(cdefs[:prod_fda_exclusion_reason])).to eq "JUST BECAUSE"
      expect(p.custom_value(cdefs[:prod_fda_unknown_reason])).to eq "NOT SURE"
      expect(p.custom_value(cdefs[:prod_fda_accession_number])).to eq "1234567890"
      expect(p.custom_value(cdefs[:prod_fda_manufacturer_name])).to eq "Some Manufacturer"
      expect(p.custom_value(cdefs[:prod_fda_warning_accepted])).to eq true

      # This is testing that the right radiation code was used and the correct qualifier is set from that
      expect(p.custom_value(cdefs[:prod_fda_affirmation_compliance])).to eq "RA1"
      expect(p.custom_value(cdefs[:prod_fda_affirmation_compliance_value])).to eq "Feb 12, 2018"

      expect(p.entity_snapshots.length).to eq 1

      s = p.entity_snapshots.first
      expect(s.context).to eq "US_PGA_FDG_date.csv"
      expect(s.user).to eq user
    end

    it "does not snapshot if nothing updates" do
      p = FactoryBot(:product, importer: importer, unique_identifier: "CMID-EL89890")
      p.update_custom_value! cdefs[:prod_fda_model_number], "31202"
      p.update_custom_value! cdefs[:prod_fda_brand_name], "CompuHyper Global"
      p.update_custom_value! cdefs[:prod_fda_product_code], "RDH"
      p.update_custom_value! cdefs[:prod_fda_contact_name], "John Allen"
      p.update_custom_value! cdefs[:prod_fda_contact_title], "Customer Representative"
      p.update_custom_value! cdefs[:prod_fda_container_type], "Box"
      p.update_custom_value! cdefs[:prod_fda_items_per_inner_container], 100
      p.update_custom_value! cdefs[:prod_fda_manufacture_date], Date.new(2018, 2, 12)
      p.update_custom_value! cdefs[:prod_fda_exclusion_reason], "JUST BECAUSE"
      p.update_custom_value! cdefs[:prod_fda_unknown_reason], "NOT SURE"
      p.update_custom_value! cdefs[:prod_fda_accession_number], "1234567890"
      p.update_custom_value! cdefs[:prod_fda_manufacturer_name], "Some Manufacturer"
      p.update_custom_value! cdefs[:prod_fda_warning_accepted], true
      p.update_custom_value! cdefs[:prod_fda_affirmation_compliance], "RA1"
      p.update_custom_value! cdefs[:prod_fda_affirmation_compliance_value], "Feb 12, 2018"

      subject.process_part_lines(user, "US_PGA_FDG_date.csv", csv_rows)

      p.reload
      expect(p.entity_snapshots.length).to eq 0
    end

    context "with alternate radiation declarations" do
      it "handles RA2 declarations" do
        DataCrossReference.create! cross_reference_type: DataCrossReference::ACE_RADIATION_DECLARATION, value: "RA2",
            key: "I / WE DECLARE THAT THE PRODUCTS ARE NOT SUBJECT TO RADIATION PERFORMANCE STANDARDS BECAUSE THEY ARE EXCLUDED BY THE APPLICABILITY CLAUSE OR DEFINITION IN THE STANDARD OR BY FDA WRITTEN GUIDANCE. SPECIFY REASON FOR EXCLUSION"
        csv_rows[0][19] = "WE DECLARE THAT THE PRODUCTS ARE NOT SUBJECT TO RADIATION PERFORMANCE STANDARDS BECAUSE THEY ARE EXCLUDED BY THE APPLICABILITY CLAUSE OR DEFINITION IN THE STANDARD OR BY FDA WRITTEN GUIDANCE. SPECIFY REASON FOR EXCLUSION"

        subject.process_part_lines(user, "US_PGA_FDG_date.csv", csv_rows)

        p = Product.first
        expect(p.custom_value(cdefs[:prod_fda_affirmation_compliance_value])).to eq "JUST BECAUSE"
        expect(p.custom_value(cdefs[:prod_fda_affirmation_compliance])).to eq "RA2"
      end

      it "handles RB2 declarations" do
        DataCrossReference.create! cross_reference_type: DataCrossReference::ACE_RADIATION_DECLARATION, value: "RB2",
            key: "I / WE DECLARE THAT THE PRODUCTS COMPLY WITH THE PERFORMANCE STANDARDS. UNKNOWN MANUFACTURER OR REPORT NUMBER. REASON NEEDED."
        csv_rows[0][19] = "I / WE DECLARE THAT THE PRODUCTS COMPLY WITH THE PERFORMANCE STANDARDS. UNKNOWN MANUFACTURER OR REPORT NUMBER. REASON NEEDED."

        subject.process_part_lines(user, "US_PGA_FDG_date.csv", csv_rows)

        p = Product.first
        expect(p.custom_value(cdefs[:prod_fda_affirmation_compliance_value])).to eq "NOT SURE"
        expect(p.custom_value(cdefs[:prod_fda_affirmation_compliance])).to eq "RB2"
      end

      it "handles declarations not requiring an affirmation of compliance qualifier" do
        DataCrossReference.create! cross_reference_type: DataCrossReference::ACE_RADIATION_DECLARATION, value: "RA4",
            key: " I / WE DECLARE THAT THE PRODUCTS ARE NOT SUBJECT TO RADIATION PERFORMANCE STANDARDS BECAUSE THEY ARE PROPERTY OF A PARTY RESIDING OUTSIDE THE U.S. AND WILL BE RETURNED TO THE OWNER AFTER REPAIR OR SERVICING"
        csv_rows[0][19] = " I / WE DECLARE THAT THE PRODUCTS ARE NOT SUBJECT TO RADIATION PERFORMANCE STANDARDS BECAUSE THEY ARE PROPERTY OF A PARTY RESIDING OUTSIDE THE U.S. AND WILL BE RETURNED TO THE OWNER AFTER REPAIR OR SERVICING"

        subject.process_part_lines(user, "US_PGA_FDG_date.csv", csv_rows)

        p = Product.first
        expect(p.custom_value(cdefs[:prod_fda_affirmation_compliance_value])).to be_nil
        expect(p.custom_value(cdefs[:prod_fda_affirmation_compliance])).to eq "RA4"
      end
    end

  end
end