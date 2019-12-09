describe OpenChain::CustomHandler::Amazon::AmazonProductDocumentsParser do

  describe "process_document" do
    let (:file_data) { IO.read 'spec/fixtures/files/attorney.png' }
    let (:filename) { "US_IOR-12345789_EE908U_Ion#Enterprises_PGA_RAD_RadiationCertificate.20191203171954407.png" }
    let! (:importer) { 
      add_system_identifier(with_customs_management_id(Factory(:importer), "CMID"), "Amazon Reference", "12345789")
    }
    let (:user) { Factory(:user) }
    let! (:inbound_file) {
      f = InboundFile.new
      allow(subject).to receive(:inbound_file).and_return f
      f
    }

    it "creates product and saves attachment" do
      expect { subject.process_document user, file_data, filename }.to change{ Product.count }.from(0).to(1)
      p = Product.last

      expect(p.unique_identifier).to eq "CMID-EE908U"
      expect(p.importer).to eq importer

      expect(p.attachments.length).to eq 1
      a = p.attachments.first
      expect(a.attached_file_name).to eq "RadiationCertificate.png"
      expect(a.attachment_type).to eq "RAD"
      expect(a.checksum).to eq Digest::SHA256.hexdigest(file_data)

      expect(p.entity_snapshots.length).to eq 1
      snap = p.entity_snapshots.first
      expect(snap.user).to eq user
      expect(snap.context).to eq filename
    end

    it "attaches to an existing product" do
      p = Product.create! unique_identifier: "CMID-EE908U", importer: importer
      expect { subject.process_document user, file_data, filename }.not_to change { Product.count }.from(1)

      p.reload
      expect(p.attachments.length).to eq 1
    end

    it "does not attach document if it's already attached" do
      p = Product.create! unique_identifier: "CMID-EE908U", importer: importer
      attachment = p.attachments.create! checksum: Digest::SHA256.hexdigest(file_data), attached_file_name: "RadiationCertificate.png"
      subject.process_document user, file_data, filename

      p.reload
      expect(p.attachments.length).to eq 1
      expect(inbound_file).to have_warning_message("File 'RadiationCertificate.png' is already attached to product CMID-EE908U.")
    end

    it "errors if filename does not match expected format" do
      expect { subject.process_document user, file_data, "filename.png" }.to raise_error "File name 'filename.png' does not appear to match the expected format for Amazon PGA documents."
    end
  end

  describe "parse" do
    subject { described_class }
    
    it "calls process_document" do
      expect_any_instance_of(subject).to receive(:process_document).with(User.integration, "data", "file.png")
      subject.parse "data", key: "file.png"
    end
  end
end