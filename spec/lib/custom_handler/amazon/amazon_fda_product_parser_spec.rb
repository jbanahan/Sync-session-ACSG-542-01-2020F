describe OpenChain::CustomHandler::Amazon::AmazonFdaProductParser do

  let (:fda_file) { IO.read 'spec/fixtures/files/amazon_fda_parts.csv' }
  let (:csv_data) { CSV.parse(fda_file) }
  
  describe "parse" do

    subject { described_class }

    it "determines file type as FDG type and calls process parts" do
      expect(subject).to receive(:new).with(:fdg).and_call_original
      expect_any_instance_of(subject).to receive(:process_parts).with(csv_data, User.integration, "/path/to/US_PGA_FDG_date.csv")

      subject.parse(fda_file, key: "/path/to/US_PGA_FDG_date.csv")
    end
  end

  describe "process_part_lines" do
    let (:user) { Factory(:user) }
    let! (:importer) { 
      add_system_identifier(with_customs_management_id(Factory(:importer), "CMID"), "Amazon Reference", "X76YHUR3GKHXS")
    }
    let (:cdefs) { subject.cdefs }
    let (:inbound_file) { InboundFile.new }
    let (:csv_rows) { [csv_data[1]] }

    before :each do 
      allow(subject).to receive(:inbound_file).and_return inbound_file
    end

    context "with FDG file type" do
      subject { described_class.new :fdg }

      it "creates product and sets FDA data" do 
        expect { subject.process_part_lines(user, "US_PGA_FDG_date.csv", csv_rows) }.to change { Product.count }.from(0).to(1)

        p = Product.first
        expect(p.importer).to eq importer
        expect(p.unique_identifier).to eq "CMID-EL89890"
        expect(p.custom_value(cdefs[:prod_fda_product])).to eq true
        expect(p.custom_value(cdefs[:prod_fda_brand_name])).to eq "CompuHyper Global"
        expect(p.custom_value(cdefs[:prod_fda_product_code])).to eq "38BEE27"

        expect(p.entity_snapshots.length).to eq 1

        s = p.entity_snapshots.first
        expect(s.context).to eq "US_PGA_FDG_date.csv"
        expect(s.user).to eq user
      end

      it "updates FDA data" do
        p = Factory(:product, importer: importer, unique_identifier: "CMID-EL89890")

        expect { subject.process_part_lines(user, "US_PGA_FDG_date.csv", csv_rows) }.not_to change { Product.count }.from(1)
        p.reload

        expect(p.custom_value(cdefs[:prod_fda_product])).to eq true
        expect(p.custom_value(cdefs[:prod_fda_brand_name])).to eq "CompuHyper Global"
        expect(p.custom_value(cdefs[:prod_fda_product_code])).to eq "38BEE27"

        expect(p.entity_snapshots.length).to eq 1

        s = p.entity_snapshots.first
        expect(s.context).to eq "US_PGA_FDG_date.csv"
        expect(s.user).to eq user
      end

      it "does not snapshot if nothing updates" do
        p = Factory(:product, importer: importer, unique_identifier: "CMID-EL89890")
        p.update_custom_value! cdefs[:prod_fda_product], true
        p.update_custom_value! cdefs[:prod_fda_brand_name], "CompuHyper Global"
        p.update_custom_value! cdefs[:prod_fda_product_code], "38BEE27"

        subject.process_part_lines(user, "US_PGA_FDG_date.csv", csv_rows)

        p.reload
        expect(p.entity_snapshots.length).to eq 0
      end
    end

    context "with FDG file type" do
      subject { described_class.new :fct }

      it "creates product and sets FDA data" do 
        expect { subject.process_part_lines(user, "US_PGA_FCT_date.csv", csv_rows) }.to change { Product.count }.from(0).to(1)

        p = Product.first
        expect(p.importer).to eq importer
        expect(p.unique_identifier).to eq "CMID-EL89890"
        expect(p.custom_value(cdefs[:prod_fda_product])).to eq true
        expect(p.custom_value(cdefs[:prod_fda_brand_name])).to eq "CompuHyper Global"
        expect(p.custom_value(cdefs[:prod_fda_product_code])).to eq "38BEE27"
        expect(p.custom_value(cdefs[:prod_fda_affirmation_compliance])).to eq "CCC"
        expect(p.custom_value(cdefs[:prod_fda_affirmation_compliance_value])).to eq "AR56T1"

        expect(p.entity_snapshots.length).to eq 1

        s = p.entity_snapshots.first
        expect(s.context).to eq "US_PGA_FCT_date.csv"
        expect(s.user).to eq user
      end

      it "updates FDA data" do
        p = Factory(:product, importer: importer, unique_identifier: "CMID-EL89890")

        expect { subject.process_part_lines(user, "US_PGA_FCT_date.csv", csv_rows) }.not_to change { Product.count }.from(1)
        p.reload

        expect(p.custom_value(cdefs[:prod_fda_product])).to eq true
        expect(p.custom_value(cdefs[:prod_fda_brand_name])).to eq "CompuHyper Global"
        expect(p.custom_value(cdefs[:prod_fda_product_code])).to eq "38BEE27"
        expect(p.custom_value(cdefs[:prod_fda_affirmation_compliance])).to eq "CCC"
        expect(p.custom_value(cdefs[:prod_fda_affirmation_compliance_value])).to eq "AR56T1"

        expect(p.entity_snapshots.length).to eq 1

        s = p.entity_snapshots.first
        expect(s.context).to eq "US_PGA_FCT_date.csv"
        expect(s.user).to eq user
      end

      it "clears affirmation of compliance and value if no value is in the file" do
        p = Factory(:product, importer: importer, unique_identifier: "CMID-EL89890")
        p.update_custom_value! cdefs[:prod_fda_affirmation_compliance], "CCC"
        p.update_custom_value! cdefs[:prod_fda_affirmation_compliance_value], "AR56T1"
        csv_rows.first[16] = ""

        expect { subject.process_part_lines(user, "US_PGA_FCT_date.csv", csv_rows) }.not_to change { Product.count }.from(1)

        p.reload
        expect(p.custom_value(cdefs[:prod_fda_affirmation_compliance])).to be_nil
        expect(p.custom_value(cdefs[:prod_fda_affirmation_compliance_value])).to be_nil

      end

      it "does not snapshot if nothing updates" do
        p = Factory(:product, importer: importer, unique_identifier: "CMID-EL89890")
        p.update_custom_value! cdefs[:prod_fda_product], true
        p.update_custom_value! cdefs[:prod_fda_brand_name], "CompuHyper Global"
        p.update_custom_value! cdefs[:prod_fda_product_code], "38BEE27"
        p.update_custom_value! cdefs[:prod_fda_affirmation_compliance], "CCC"
        p.update_custom_value! cdefs[:prod_fda_affirmation_compliance_value], "AR56T1"

        subject.process_part_lines(user, "US_PGA_FCT_date.csv", csv_rows)

        p.reload
        expect(p.entity_snapshots.length).to eq 0
      end
    end
  end
end