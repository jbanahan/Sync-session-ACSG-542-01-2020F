describe OpenChain::CustomHandler::Amazon::AmazonCvdAddProductParser do

  let (:add_file) { IO.read 'spec/fixtures/files/amazon_add_parts.csv' }
  let (:cvd_file) { IO.read 'spec/fixtures/files/amazon_cvd_parts.csv' }
  let (:add_csv_data) { CSV.parse(add_file) }
  let (:cvd_csv_data) { CSV.parse(cvd_file) }

  describe "parse" do

    subject { described_class }

    it "determines file type as ADD type and calls process parts" do
      expect(subject).to receive(:new).with(:add).and_call_original
      expect_any_instance_of(subject).to receive(:process_parts).with(add_csv_data, User.integration, "/path/to/US_PGA_ADD_date.csv")

      subject.parse(add_file, key: "/path/to/US_PGA_ADD_date.csv")
    end
  end

  describe "process_part_lines" do
    let (:user) { create(:user) }
    let! (:importer) {
      add_system_identifier(with_customs_management_id(create(:importer), "CMID"), "Amazon Reference", "X76YHUR3GKHXS")
    }
    let (:cdefs) { subject.cdefs }
    let (:inbound_file) { InboundFile.new }

    before :each do
      allow(subject).to receive(:inbound_file).and_return inbound_file
    end

    context "with ADD file type" do
      let (:csv_rows) { [add_csv_data[1]] }

      subject { described_class.new :add }

      it "creates product and sets FDA data" do
        expect { subject.process_part_lines(user, "US_PGA_ADD_date.csv", csv_rows) }.to change { Product.count }.from(0).to(1)

        p = Product.first
        expect(p.importer).to eq importer
        expect(p.unique_identifier).to eq "CMID-EL89890"
        expect(p.custom_value(cdefs[:prod_add_case])).to eq "A-462-809"
        expect(p.custom_value(cdefs[:prod_add_disclaimed])).to eq true
        expect(p.custom_value(cdefs[:prod_cvd_case])).to be_nil
        expect(p.custom_value(cdefs[:prod_cvd_disclaimed])).to be_nil

        expect(p.entity_snapshots.length).to eq 1

        s = p.entity_snapshots.first
        expect(s.context).to eq "US_PGA_ADD_date.csv"
        expect(s.user).to eq user
      end

      it "updates FDA data" do
        p = create(:product, importer: importer, unique_identifier: "CMID-EL89890")

        expect { subject.process_part_lines(user, "US_PGA_ADD_date.csv", csv_rows) }.not_to change { Product.count }.from(1)
        p.reload

        expect(p.custom_value(cdefs[:prod_add_case])).to eq "A-462-809"
        expect(p.custom_value(cdefs[:prod_add_disclaimed])).to eq true
        expect(p.custom_value(cdefs[:prod_cvd_case])).to be_nil
        expect(p.custom_value(cdefs[:prod_cvd_disclaimed])).to be_nil

        expect(p.entity_snapshots.length).to eq 1

        s = p.entity_snapshots.first
        expect(s.context).to eq "US_PGA_ADD_date.csv"
        expect(s.user).to eq user
      end

      it "does not snapshot if nothing updates" do
        p = create(:product, importer: importer, unique_identifier: "CMID-EL89890")
        p.update_custom_value! cdefs[:prod_add_case], "A-462-809"
        p.update_custom_value! cdefs[:prod_add_disclaimed], true

        subject.process_part_lines(user, "US_PGA_ADD_date.csv", csv_rows)

        p.reload
        expect(p.entity_snapshots.length).to eq 0
      end
    end

    context "with CVD file type" do
      let (:csv_rows) { [cvd_csv_data[1]] }
      subject { described_class.new :cvd }

      it "creates product and sets CVD data" do
        expect { subject.process_part_lines(user, "US_PGA_CVD_date.csv", csv_rows) }.to change { Product.count }.from(0).to(1)

        p = Product.first
        expect(p.importer).to eq importer
        expect(p.unique_identifier).to eq "CMID-EL89890"
        expect(p.custom_value(cdefs[:prod_cvd_case])).to eq "C-462-809"
        expect(p.custom_value(cdefs[:prod_cvd_disclaimed])).to eq true
        expect(p.custom_value(cdefs[:prod_add_case])).to be_nil
        expect(p.custom_value(cdefs[:prod_add_disclaimed])).to be_nil

        expect(p.entity_snapshots.length).to eq 1

        s = p.entity_snapshots.first
        expect(s.context).to eq "US_PGA_CVD_date.csv"
        expect(s.user).to eq user
      end

      it "updates CVD data" do
        p = create(:product, importer: importer, unique_identifier: "CMID-EL89890")

        expect { subject.process_part_lines(user, "US_PGA_CVD_date.csv", csv_rows) }.not_to change { Product.count }.from(1)
        p.reload

        expect(p.custom_value(cdefs[:prod_cvd_case])).to eq "C-462-809"
        expect(p.custom_value(cdefs[:prod_cvd_disclaimed])).to eq true
        expect(p.custom_value(cdefs[:prod_add_case])).to be_nil
        expect(p.custom_value(cdefs[:prod_add_disclaimed])).to be_nil

        expect(p.entity_snapshots.length).to eq 1

        s = p.entity_snapshots.first
        expect(s.context).to eq "US_PGA_CVD_date.csv"
        expect(s.user).to eq user
      end

      it "does not snapshot if nothing updates" do
        p = create(:product, importer: importer, unique_identifier: "CMID-EL89890")
        p.update_custom_value! cdefs[:prod_cvd_case], "C-462-809"
        p.update_custom_value! cdefs[:prod_cvd_disclaimed], true

        subject.process_part_lines(user, "US_PGA_CVD_date.csv", csv_rows)

        p.reload
        expect(p.entity_snapshots.length).to eq 0
      end
    end
  end
end