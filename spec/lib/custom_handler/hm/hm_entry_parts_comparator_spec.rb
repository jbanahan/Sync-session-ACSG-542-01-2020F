describe OpenChain::CustomHandler::Hm::HmEntryPartsComparator do

  describe "accept?" do

    let (:importer) { Company.new system_code: "HENNE" }
    let (:entry) { Entry.new customer_number: "HENNE", source_system: "Alliance", importer: importer, broker_reference: "REF", file_logged_date: Time.zone.parse("2016-11-22 00:00"), export_country_codes: "CN" }
    let (:snapshot) { EntitySnapshot.new recordable: entry}

    it "accepts entry snapshots for HM" do
      expect(described_class.accept? snapshot).to eq true
    end

    it "does not accept non-HM entries" do
      entry.customer_number = "NOT-HM"
      expect(described_class.accept? snapshot).to eq false
    end

    it "does not accept non-Kewill entries" do
      entry.source_system = "NOT-Alliance"
      expect(described_class.accept? snapshot).to eq false
    end

    it "does not accept entries with an export country of Canada" do
      entry.export_country_codes = "CA"
      expect(described_class.accept? snapshot).to eq false
    end
  end


  describe "compare" do
    let (:importer) { create(:importer, system_code: "HENNE")}
    let (:entry) {
      e = create(:entry, customer_number: "HENNE", source_system: "Alliance", importer: importer, broker_reference: "REF", file_logged_date: Time.zone.parse("2016-11-22 00:00"))
      e.broker_invoices.create! invoice_number: "BROK", invoice_total: BigDecimal("10")
      e
    }
    let (:snapshot_json) { JSON.parse(CoreModule::ENTRY.entity_json entry) }
    let (:snapshot) { entry.create_snapshot user }
    let (:user) { create(:user) }
    let (:cdefs) { subject.cdefs }
    let (:us) { Country.where(iso_code: "US").first_or_create! }
    let (:official_tariff) { OfficialTariff.create! country_id: us.id, hts_code: "1234567890"}
    let (:invoice) { create(:commercial_invoice, entry: entry, invoice_number: "12345") }
    let (:invoice_line) { create(:commercial_invoice_line, commercial_invoice: invoice, part_number: "PART", quantity: 5) }
    let (:invoice_tariff) { create(:commercial_invoice_tariff, commercial_invoice_line: invoice_line, entered_value: 10, hts_code: "1234567890", tariff_description: "Description") }

    before :each do
      us
      official_tariff
      invoice_tariff
    end

    context "with default snapshot" do

      before :each do
        expect(subject).to receive(:get_json_hash).and_return snapshot_json
        snapshot
      end

      it "creates products" do
        subject.compare nil, nil, nil, snapshot.bucket, snapshot.doc_path, snapshot.version

        products = Product.where(importer_id: importer.id).all
        expect(products.size).to eq 1

        prod = products.first
        expect(prod.unique_identifier).to eq "HENNE-PART"
        expect(prod.classifications.size).to eq 1
        c = prod.classifications.first
        expect(c.country).to eq us
        expect(c.custom_value(cdefs[:class_customs_description])).to eq "Description"
        expect(c.tariff_records.size).to eq 1
        expect(c.tariff_records.first.hts_1).to eq "1234567890"
        expect(prod.custom_value(cdefs[:prod_part_number])).to eq "PART"
        expect(prod.custom_value(cdefs[:prod_value_order_number])).to eq "12345"
        expect(prod.custom_value(cdefs[:prod_value])).to eq BigDecimal.new("2")
        expect(prod.entity_snapshots.length).to eq 1
        expect(prod.entity_snapshots.first.context).to eq "H&M Entry Parts"

        entry.reload
        sr = entry.sync_records.find {|sr| sr.trading_partner == "H&M Parts"}
        expect(sr).not_to be_nil
      end

      it "updates existing products with classification, does not update value" do
        product = create(:classification, country: us, product: create(:product, importer: importer, unique_identifier: "HENNE-PART")).product
        # Higher last digit value is used (note trimmming of the A)
        product.update_custom_value! cdefs[:prod_value_order_number], "12346A"

        subject.compare nil, nil, nil, snapshot.bucket, snapshot.doc_path, snapshot.version

        products = Product.where(importer_id: importer.id).all
        expect(products.size).to eq 1
        prod = products.first
        expect(prod.classifications.first.tariff_records.size).to eq 1
        expect(prod.classifications.first.tariff_records.first.hts_1).to eq "1234567890"
        expect(prod.custom_value(cdefs[:prod_value])).to be_nil
        expect(prod.entity_snapshots.length).to eq 1
      end

      it "does not update existing product if information is the same" do
        classification = create(:classification, country: us, product: create(:product, importer: importer, unique_identifier: "HENNE-PART"))
        classification.update_custom_value! cdefs[:class_customs_description], "Description"
        classification.tariff_records.create! hts_1: "1234567890"

        product = classification.product
        product.update_custom_value! cdefs[:prod_value_order_number], "12346A"

        subject.compare nil, nil, nil, snapshot.bucket, snapshot.doc_path, snapshot.version
        prod = Product.where(importer_id: importer.id).first
        expect(prod.entity_snapshots.length).to eq 0
      end

      it "adds US classifications to existing products that don't have one" do
        prod = create(:product, importer: importer, unique_identifier: "HENNE-PART")
        subject.compare nil, nil, nil, snapshot.bucket, snapshot.doc_path, snapshot.version

        prod.reload
        expect(prod.classifications.size).to eq 1
        c = prod.classifications.first
        expect(c.country).to eq us
        expect(c.custom_value(cdefs[:class_customs_description])).to eq "Description"
      end

      it "does not replace classifications if product was updated by a newer entry" do
        new_entry = create(:entry, customer_number: "HENNE", source_system: "Alliance", importer: importer, broker_reference: "NEWER REF", file_logged_date: Time.zone.parse("2016-11-23 00:00"))
        prod = create(:classification, country: us, product: create(:product, importer: importer, unique_identifier: "HENNE-PART")).product
        prod.classifications.first.tariff_records.create! hts_1: "9876543210"
        prod.update_custom_value! cdefs[:prod_classified_from_entry], "NEWER REF"

        subject.compare nil, nil, nil, snapshot.bucket, snapshot.doc_path, snapshot.version

        prod.reload
        expect(prod.classifications.first.tariff_records.first.hts_1).to eq "9876543210"
      end

      it "replaces the classification if entry is newer than existing entry link" do
        new_entry = create(:entry, customer_number: "HENNE", source_system: "Alliance", importer: importer, broker_reference: "NEWER REF", file_logged_date: Time.zone.parse("2016-11-21 00:00"))
        prod = create(:classification, country: us, product: create(:product, importer: importer, unique_identifier: "HENNE-PART")).product
        prod.classifications.first.tariff_records.create! hts_1: "9876543210"
        prod.update_custom_value! cdefs[:prod_classified_from_entry], "NEWER REF"

        subject.compare nil, nil, nil, snapshot.bucket, snapshot.doc_path, snapshot.version

        prod.reload
        expect(prod.classifications.first.tariff_records.first.hts_1).to eq "1234567890"
      end

      context "with class compare method" do
        it "works" do
          subject.compare nil, nil, nil, snapshot.bucket, snapshot.doc_path, snapshot.version
          prod = Product.where(importer_id: importer.id).first
          expect(prod.entity_snapshots.length).to eq 1
        end
      end

      context "with 'special' tariffs" do
        ["9802", "9902", "9903", "9908"].each do |tariff|
          before :each do
            invoice_line.commercial_invoice_tariffs.create! entered_value: 10, hts_code: "1234567890", tariff_description: "Description"
            invoice_tariff.update_attributes! entered_value: 0, hts_code: tariff, tariff_description: "Special Tariff"
          end

          it "skips special tariff number" do
            subject.compare nil, nil, nil, snapshot.bucket, snapshot.doc_path, snapshot.version
            prod = Product.first
            expect(prod.classifications.first.tariff_records.first.hts_1).to eq "1234567890"
          end
        end
      end
    end

    it "does nothing if the entry hasn't been billed" do
      entry.broker_invoices.destroy_all
      expect(subject).to receive(:get_json_hash).and_return snapshot_json

      subject.compare nil, nil, nil, snapshot.bucket, snapshot.doc_path, snapshot.version
      entry.reload
      expect(entry.sync_records.length).to eq 0
    end

    it "skips lines without part numbers" do
      entry.commercial_invoice_lines.first.update_attributes! part_number: ""
      entry.reload
      expect(subject).to receive(:get_json_hash).and_return snapshot_json

      subject.compare nil, nil, nil, snapshot.bucket, snapshot.doc_path, snapshot.version
      products = Product.where(importer_id: importer.id).all
      expect(products.size).to eq 0
    end
  end
end