describe OpenChain::CustomHandler::Hm::HmEntryDocsComparator do

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


  describe "compare", :snapshot do
    let (:importer) { create(:importer, system_code: "HENNE")}
    let (:entry) { create(:entry, customer_number: "HENNE", source_system: "Alliance", importer: importer, broker_reference: "REF", file_logged_date: Time.zone.parse("2016-11-22 00:00")) }
    let (:snapshot) { entry.create_snapshot user }
    let (:user) { create(:user) }
    let (:tempfile) { Tempfile.new(['testfile', '.pdf']) }
    let (:cdefs) { subject.cdefs}
    let (:us) { Country.where(iso_code: "US").first_or_create! }
    let (:official_tariff) { OfficialTariff.create! country_id: us.id, hts_code: "1234567890"}
    let (:broker_invoice) { create(:broker_invoice, entry: entry)}

    before :each do
      us
      official_tariff
      invoice = create(:commercial_invoice, entry: entry, invoice_number: "12345")
      invoice_line = create(:commercial_invoice_line, commercial_invoice: invoice, part_number: "PART", quantity: 5)
      invoice_tariff = create(:commercial_invoice_tariff, commercial_invoice_line: invoice_line, entered_value: 10, hts_code: "1234567890", tariff_description: "Description")
      broker_invoice

      entry.attachments.create! attachment_type: "Entry Packet", attached_file_name: "file.pdf", attached_file_size: 1, attached_updated_at: Time.zone.now

      snapshot
      allow_any_instance_of(Attachment).to receive(:download_to_tempfile).and_yield tempfile
    end

    after :each do
      tempfile.close! unless tempfile.closed?
    end


    it "creates products and copies entry attachments to new products" do
      subject.compare nil, nil, nil, snapshot.bucket, snapshot.doc_path, snapshot.version

      products = Product.where(importer_id: importer.id).all
      expect(products.size).to eq 1

      prod = products.first
      expect(prod.unique_identifier).to eq "HENNE-PART"
      expect(prod.custom_value(cdefs[:prod_part_number])).to eq "PART"
      expect(prod.entity_snapshots.length).to eq 1

      expect(prod.attachments.length).to eq 1
      att = prod.attachments.first
      expect(att.attached_file_name).to eq "Entry Packet - REF.pdf"
    end

    it "moves attachments even if attachment is in both old and new snapshot" do
      # This is to check to handle the case where the attachment is added at a point in time where the business rules
      # failed.  The attachment needs to be added at a later time, but at that point the attachment will be in the snapshots
      # and not detected as a change.

      # just use the same snapshot for both old / new that way the snapshot will be identical and the docs won't be moved
      subject.compare snapshot.bucket, snapshot.doc_path, snapshot.version, snapshot.bucket, snapshot.doc_path, snapshot.version

      prod = Product.where(importer_id: importer.id).first
      expect(prod.attachments.length).to eq 1
      expect(prod.attachments.first.attached_file_name).to eq "Entry Packet - REF.pdf"
    end

    it "removes existing Entry Packet attachment from product when an updated one is attached to the entry" do
      product = create(:classification, country: us, product: create(:product, importer: importer, unique_identifier: "HENNE-PART")).product
      existing_attachment = product.attachments.create! attached_file_name: "Entry Packet - REF.pdf", attachment_type: "Entry Packet"

      subject.compare nil, nil, nil, snapshot.bucket, snapshot.doc_path, snapshot.version
      prod = Product.where(importer_id: importer.id).first
      expect(prod.attachments.length).to eq 1
      expect(prod.attachments.first).not_to eq existing_attachment
    end

    it "skips adding attachment if product already has it" do
      product = create(:classification, country: us, product: create(:product, importer: importer, unique_identifier: "HENNE-PART")).product
      existing_attachment = product.attachments.create! attached_file_name: "Entry Packet - REF.pdf", attachment_type: "Entry Packet", attached_file_size: 1

      subject.compare nil, nil, nil, snapshot.bucket, snapshot.doc_path, snapshot.version
      prod = Product.where(importer_id: importer.id).first
      expect(prod.attachments.length).to eq 1
      expect(prod.attachments.first).to eq existing_attachment
    end

    it "skips lines without part numbers" do
      entry.commercial_invoice_lines.first.update_attributes! part_number: ""
      entry.reload
      new_snapshot = entry.create_snapshot user

      subject.compare nil, nil, nil, new_snapshot.bucket, new_snapshot.doc_path, new_snapshot.version
      products = Product.where(importer_id: importer.id).all
      expect(products.size).to eq 0
    end

    it "no-ops if entry has already been synced and attachment is not newer than sync record" do
      entry.sync_records.create! trading_partner: "H&M Docs", sent_at: (Time.zone.now + 1.day)

      snapshot = entry.create_snapshot user
      subject.compare nil, nil, nil, snapshot.bucket, snapshot.doc_path, snapshot.version
      # Product won't exist because the sync record was already added.
      expect(Product.where(importer_id: importer.id).first).to be_nil
    end

    it "re-runs if entry has been synced by attachment is newer than sync record" do
      entry.sync_records.create! trading_partner: "H&M Docs", sent_at: (Time.zone.now - 1.day)

      snapshot = entry.create_snapshot user
      subject.compare nil, nil, nil, snapshot.bucket, snapshot.doc_path, snapshot.version
      p = Product.where(importer_id: importer.id).first
      expect(p.attachments.length).to eq 1
    end

    it "no-ops if there are no broker invoices" do
      broker_invoice.destroy
      entry.reload
      snapshot = entry.create_snapshot user
      subject.compare nil, nil, nil, snapshot.bucket, snapshot.doc_path, snapshot.version
      expect(Product.where(importer_id: importer.id).first).to be_nil
    end

    context "with class compare method" do
      it "works" do
        subject.compare nil, nil, nil, snapshot.bucket, snapshot.doc_path, snapshot.version
        prod = Product.where(importer_id: importer.id).first
        expect(prod.attachments.length).to eq 1
        expect(prod.entity_snapshots.length).to eq 1
      end
    end
  end
end