describe OpenChain::CustomHandler::Vandegrift::VandegriftEntryArchiveComparator do
  subject { described_class.new }
  let(:e) { Factory(:entry, entry_number: "12345", customer_number: "CUSTNUM", importer: Factory(:company)) }
  
  describe "accept?" do
    let!(:snap) { Factory(:entity_snapshot, recordable: e) }
    let!(:bi) { Factory(:broker_invoice, entry: e, invoice_date: Date.new(2018,1,1)) }
    let!(:aas) { Factory(:attachment_archive_setup, company: e.importer, start_date: Date.new(2018,1,1), end_date: Date.new(2018,1,1), send_in_real_time: true) }

    it "returns true for entries with 'real time' flag enabled" do
      expect(described_class.accept? snap).to eq true
    end

    it "returns true for entries with importer parent setups with 'real time' flag enabled" do
      parent = Factory(:company)
      parent.linked_companies << e.importer
      aas.update! company_id: parent.id

      expect(described_class.accept? snap).to eq true
    end

    it "returns false when 'real time' flag is disabled" do
      aas.update_attributes! send_in_real_time: nil
      expect(described_class.accept? snap).to eq false
    end
    
    it "return false for non-entries" do
      snap.update_attributes! recordable: Factory(:product)
      expect(described_class.accept? snap).to eq false
    end

    it "returns true if at least one broker invoice is after the archive setup's start_date and there is no end_date" do
      aas.update_attributes end_date: nil
      expect(described_class.accept? snap).to eq true
    end

    it "returns false if all broker invoices are earlier the the archive setup's start/end range" do
      e.broker_invoices.first.update_attributes! invoice_date: Date.new(2017,12,31)
      expect(described_class.accept? snap).to eq false
    end

    it "returns false if all broker invoices are after the the archive setup's start/end range" do
      e.broker_invoices.first.update_attributes! invoice_date: Date.new(2018,1,2)
      expect(described_class.accept? snap).to eq false
    end
  end

  describe "compare" do
    let(:att) { Factory(:attachment, attachable: e) }
    let(:old_entry) do
      {"entity" => {"core_module" => "Entry", "children" => 
        [{"entity" => {"core_module" => "Attachment", "record_id" => att.id - 1, "model_fields" => {"att_attachment_type" => "Archive Packet"}}},
         {"entity" => {"core_module" => "Attachment", "record_id" => 300, "model_fields" => {"att_attachment_type" => "Invoice"}}}]}}
    end
    let(:new_entry) do
      {"entity" => {"core_module" => "Entry", "children" => 
        [{"entity" => {"core_module" => "Attachment", "record_id" => att.id, "model_fields" => {"att_attachment_type" => "Archive Packet"}}},
         {"entity" => {"core_module" => "Attachment", "record_id" => 300, "model_fields" => {"att_attachment_type" => "Invoice"}}}]}}
    end
 
    it "FTPs archive if its ID has changed" do
      expect(subject).to receive(:get_json_hash).with("new bucket", "new path", "new version").and_return new_entry
      expect(subject).to receive(:get_json_hash).with("old bucket", "old path", "old version").and_return old_entry
      expect(subject).to receive(:ftp_archive).with att

      subject.compare "Entry", e.id, "old bucket", "old path", "old version", "new bucket", "new path", "new version"
    end

    it "does nothing if archive ID hasn't changed" do
      old_entry["entity"]["children"][0]["entity"]["record_id"] = 1
      new_entry["entity"]["children"][0]["entity"]["record_id"] = 1
      expect(subject).to receive(:get_json_hash).with("new bucket", "new path", "new version").and_return new_entry
      expect(subject).to receive(:get_json_hash).with("old bucket", "old path", "old version").and_return old_entry
      expect(subject).to_not receive(:ftp_archive)

      subject.compare "Entry", e.id, "old bucket", "old path", "old version", "new bucket", "new path", "new version"
    end
  end

  describe "ftp_archive" do
    let(:att) { Factory(:attachment, attachable: e, attachment_type: "Archive Packet") }
    let!(:aas) { Factory(:attachment_archive_setup, company: e.importer, start_date: Date.new(2018,1,1), end_date: Date.new(2018,1,1), send_in_real_time: true) }


    it "FTPs attachment using entry's customer number for file name and destination path" do
      ftp_opts = "ftp opts"
      attachment_tempfile = instance_double(Tempfile)
      expect(att).to receive(:bucket).and_return "bucket"
      expect(att).to receive(:path).and_return "path"
      expect(OpenChain::S3).to receive(:download_to_tempfile).with("bucket", "path", {original_filename: "12345_Archive_Packet_201803152030.pdf"}).and_yield attachment_tempfile
      expect(subject).to receive(:connect_vfitrack_net).with("to_ecs/attachment_archive/CUSTNUM").and_return ftp_opts
      expect(subject).to receive(:ftp_file).with(attachment_tempfile, ftp_opts)

      Timecop.freeze(DateTime.new(2018,3,15,20,30)) { subject.ftp_archive att }
    end

    it "uses CustomerNumber defined in the archive setup to send" do
      aas.update! send_as_customer_number: "XXXXX"
      ftp_opts = "ftp opts"
      attachment_tempfile = instance_double(Tempfile)
      expect(att).to receive(:bucket).and_return "bucket"
      expect(att).to receive(:path).and_return "path"
      expect(OpenChain::S3).to receive(:download_to_tempfile).with("bucket", "path", {original_filename: "12345_Archive_Packet_201803152030.pdf"}).and_yield attachment_tempfile
      expect(subject).to receive(:connect_vfitrack_net).with("to_ecs/attachment_archive/XXXXX").and_return ftp_opts
      expect(subject).to receive(:ftp_file).with(attachment_tempfile, ftp_opts)

      Timecop.freeze(DateTime.new(2018,3,15,20,30)) { subject.ftp_archive att }
    end
  end
end
