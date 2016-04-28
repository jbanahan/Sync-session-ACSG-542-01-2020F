require 'spec_helper'

describe OpenChain::CustomHandler::Hm::HmEntryDocsComparator do

  let (:importer) { Factory(:importer, system_code: "HENNE")}
  let (:entry) { Factory(:entry, customer_number: "HENNE", source_system: "Alliance", importer: importer, broker_reference: "REF") }
  let (:snapshot) { entry.create_snapshot user }
  let (:user) { Factory(:user) }


  describe "accept?" do
    it "accepts entry snapshots for HM" do
      expect(described_class.accept? snapshot).to be_true
    end

    it "does not accept non-HM entries" do
      entry.update_attributes! customer_number: "NOT-HM"
      expect(described_class.accept? snapshot).to be_false
    end

    it "does not accept non-Kewill entries" do
      entry.update_attributes! source_system: "NOT-Alliance"
      expect(described_class.accept? snapshot).to be_false
    end
  end


  describe "compare" do

    let (:tempfile) { Tempfile.new(['testfile', '.pdf']) }
    let (:cdefs) { subject.instance_variable_get("@cdefs")}
    let (:us) { Country.where(iso_code: "US").first_or_create! }

    before :each do
      us
      invoice = Factory(:commercial_invoice, entry: entry, invoice_number: "12345")
      invoice_line = Factory(:commercial_invoice_line, commercial_invoice: invoice, part_number: "PART", quantity: 5)
      invoice_tariff = Factory(:commercial_invoice_tariff, commercial_invoice_line: invoice_line, entered_value: 10, hts_code: "1234567890")

      entry.attachments.create! attachment_type: "Entry Packet", attached_file_name: "file.pdf", attached_file_size: 1

      snapshot
      Attachment.any_instance.stub(:download_to_tempfile).and_yield tempfile
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
      expect(prod.classifications.size).to eq 1
      expect(prod.classifications.first.tariff_records.size).to eq 1
      expect(prod.classifications.first.tariff_records.first.hts_1).to eq "1234567890"
      expect(prod.custom_value(cdefs[:prod_part_number])).to eq "PART"
      expect(prod.custom_value(cdefs[:prod_value_order_number])).to eq "12345"
      expect(prod.custom_value(cdefs[:prod_value])).to eq BigDecimal.new("2")
      expect(prod.entity_snapshots.length).to eq 1

      expect(prod.attachments.length).to eq 1
      att = prod.attachments.first
      expect(att.attached_file_name).to eq "Entry Packet - REF - file.pdf"
    end

    it "updates existing products with classification, does not update value" do
      product = Factory(:classification, country: us, product: Factory(:product, importer: importer, unique_identifier: "HENNE-PART")).product
      # Higher last digit value is used (note trimmming of the A)
      product.update_custom_value! cdefs[:prod_value_order_number], "12346A"

      subject.compare nil, nil, nil, snapshot.bucket, snapshot.doc_path, snapshot.version

      products = Product.where(importer_id: importer.id).all
      expect(products.size).to eq 1
      prod = products.first
      expect(prod.classifications.first.tariff_records.size).to eq 1
      expect(prod.classifications.first.tariff_records.first.hts_1).to eq "1234567890"
      expect(prod.custom_value(cdefs[:prod_value])).to be_nil
      expect(prod.attachments.length).to eq 1
      expect(prod.entity_snapshots.length).to eq 1
    end

    it "does not update existing product if information is the same" do
      classification = Factory(:classification, country: us, product: Factory(:product, importer: importer, unique_identifier: "HENNE-PART"))
      classification.tariff_records.create! hts_1: "1234567890"

      product = classification.product
      product.update_custom_value! cdefs[:prod_value_order_number], "12346A"

      subject.compare nil, nil, nil, snapshot.bucket, snapshot.doc_path, snapshot.version
      prod = Product.where(importer_id: importer.id).first
      expect(prod.entity_snapshots.length).to eq 0
    end

    it "moves attachments even if attachment is in both old and new snapshot" do
      # This is to check to handle the case where the attachment is added at a point in time where the business rules
      # failed.  The attachment needs to be added at a later time, but at that point the attachment will be in the snapshots 
      # and not detected as a change.

      # just use the same snapshot for both old / new that way the snapshot will be identical and the docs won't be moved
      subject.compare snapshot.bucket, snapshot.doc_path, snapshot.version, snapshot.bucket, snapshot.doc_path, snapshot.version

      prod = Product.where(importer_id: importer.id).first
      expect(prod.attachments.length).to eq 1
      expect(prod.attachments.first.attached_file_name).to eq "Entry Packet - REF - file.pdf"
    end

    it "removes existing Entry Packet attachment from product when an updated one is attached to the entry" do
      product = Factory(:classification, country: us, product: Factory(:product, importer: importer, unique_identifier: "HENNE-PART")).product
      existing_attachment = product.attachments.create! attached_file_name: "Entry Packet - REF - file.pdf", attachment_type: "Entry Packet"

      subject.compare nil, nil, nil, snapshot.bucket, snapshot.doc_path, snapshot.version
      prod = Product.where(importer_id: importer.id).first
      expect(prod.attachments.length).to eq 1
      expect(prod.attachments.first).not_to eq existing_attachment
    end

    it "skips adding attachment if product already has it" do
      product = Factory(:classification, country: us, product: Factory(:product, importer: importer, unique_identifier: "HENNE-PART")).product
      existing_attachment = product.attachments.create! attached_file_name: "Entry Packet - REF - file.pdf", attachment_type: "Entry Packet", attached_file_size: 1

      subject.compare nil, nil, nil, snapshot.bucket, snapshot.doc_path, snapshot.version
      prod = Product.where(importer_id: importer.id).first
      expect(prod.attachments.length).to eq 1
      expect(prod.attachments.first).to eq existing_attachment
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