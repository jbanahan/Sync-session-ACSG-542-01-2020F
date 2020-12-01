describe OpenChain::CustomHandler::Amazon::AmazonProductParser do

  let! (:country_origin) { FactoryBot(:country, iso_code: "CN") }
  let! (:us) { FactoryBot(:country, iso_code: "US") }
  let (:data) { IO.read 'spec/fixtures/files/amazon_parts.csv' }
  let (:csv_data) { CSV.parse(data) }
  let! (:importer) {
    add_system_identifier(with_customs_management_id(FactoryBot(:importer), "CMID"), "Amazon Reference", "ABC4439203")
  }
  let (:user) { FactoryBot(:user) }
  let (:cdefs) { subject.cdefs }
  let (:inbound_file) { InboundFile.new }

  describe "parse" do

    before :each do
      allow(subject).to receive(:inbound_file).and_return inbound_file
    end

    def expect_cdef(obj, uid)
      expect(obj.custom_value(cdefs[uid]))
    end

    it "parses product data" do
      expect { subject.process_parts csv_data, user, "file.csv" }.to change { Product.count }.from(0).to(1)
      p = Product.first
      expect(p.importer).to eq importer
      expect(p.unique_identifier).to eq "CMID-HJE9870"
      expect(p.unit_of_measure).to eq "Peice"
      expect(p.name).to eq "Lightclub Nordic Sunglasses Flower Girl Canvas Frameless Indoor Wall Painting Decoration For Beautiful Homes"
      expect_cdef(p, :prod_part_number).to eq "HJE9870"
      expect_cdef(p, :prod_importer_style).to eq "B07FD98S4D"
      expect_cdef(p, :prod_country_of_origin).to eq "CN"
      expect_cdef(p, :prod_add_case).to eq "ADD123"
      expect_cdef(p, :prod_add_case_2).to be_nil
      expect_cdef(p, :prod_cvd_case).to eq "CVD123"
      expect_cdef(p, :prod_cvd_case_2).to be_nil

      expect(p.entity_snapshots.length).to eq 1
      s = p.entity_snapshots.first
      expect(s.user).to eq user
      expect(s.context).to eq "file.csv"

      expect(p.classifications.length).to eq 1
      c = p.classifications.first

      expect(c.country).to eq us
      expect_cdef(c, :class_binding_ruling_number).to eq "RULING"
      expect_cdef(c, :class_classification_notes).to eq "NOTES"

      expect(c.tariff_records.length).to eq 1
      t = c.tariff_records.first
      expect(t.line_number).to eq 1
      expect(t.hts_1).to eq "9802541234"

      m = p.manufacturer
      expect(m.address_type).to eq "MID"
      expect(m.system_code).to eq "CNGRE45BEJ"
      expect(m.name).to eq "THE GREENHOUSE"
      expect(m.line_1).to eq "USGRE45BIR 45 Royal Crescent"
      expect(m.line_2).to eq "Dongcheng"
      expect(m.city).to eq "Beijing"
      expect(m.postal_code).to eq "100010"
      expect(m.country).to eq country_origin
    end

    it "handles multiple lines, adding multiple tariffs" do
      csv_data << csv_data[1].dup
      csv_data[2][18] = "9876543210"

      subject.process_parts csv_data, user, "file.csv"

      p = Product.first
      expect(p.hts_for_country(us)).to eq ["9802541234", "9876543210"]
    end

    it "updates existing product" do
      p = FactoryBot(:product, importer: importer, unique_identifier: "CMID-HJE9870", name: "Desc")
      subject.process_parts csv_data, user, "file.csv"

      p.reload
      expect(p.name).to eq "Lightclub Nordic Sunglasses Flower Girl Canvas Frameless Indoor Wall Painting Decoration For Beautiful Homes"
    end

    it "syncs tariff records to what is in the file" do
      p = FactoryBot(:product, importer: importer, unique_identifier: "CMID-HJE9870", name: "Desc")
      p.update_hts_for_country(us, ["1234567890", "9876543210"])

      subject.process_parts csv_data, user, "file.csv"
      p.reload
      expect(p.hts_for_country(us)).to eq ["9802541234"]
    end

    it "does not snapshot if no updates are made" do
      subject.process_parts csv_data, user, "file.csv"
      p = Product.first
      subject.process_parts csv_data, user, "file.csv"
      p.reload
      expect(p.entity_snapshots.length).to eq 1
    end

    it "marks parts inactive if instructed" do
      p = FactoryBot(:product, importer: importer, unique_identifier: "CMID-HJE9870")
      csv_data[1][0] = "Delete"
      subject.process_parts csv_data, user, "file.csv"
      p.reload
      expect(p).to be_inactive
      expect(p.entity_snapshots.length).to eq 1
      s = p.entity_snapshots.first
      expect(s.user).to eq user
      expect(s.context).to eq "file.csv"
    end

    it "records a reject message if the importer is missing" do
      csv_data[1][1] = "INVALIDIOR"
      subject.process_parts csv_data, user, "file.csv"

      expect(inbound_file).to have_reject_message("Failed to find Amazon Importer with IOR Id 'INVALIDIOR'.")

    end
  end

  describe "parse" do
    subject { described_class }

    it "converts data to csv and processes parts" do
      expect_any_instance_of(subject).to receive(:process_parts) do |inst, csv, user, filename|
        expect(csv).to eq csv_data
        expect(user).to eq User.integration
        expect(filename).to eq "file.txt"
      end
      subject.parse(data, {key: "file.txt"})
    end
  end
end