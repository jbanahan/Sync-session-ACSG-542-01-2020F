require 'spec_helper'

describe OpenChain::CustomHandler::Vandegrift::VandegriftEntryArchiveComparator do
  subject { described_class.new }
  let(:e) { Factory(:entry, entry_number: "12345", customer_number: "CUSTNUM", importer: Factory(:company)) }
  
  describe "accept?" do
    let!(:snap) { Factory(:entity_snapshot, recordable: e) }
    let!(:bi) { Factory(:broker_invoice, entry: e, invoice_date: Date.new(2018,1,10)) }
    let!(:aas) { Factory(:attachment_archive_setup, company: e.importer, start_date: Date.new(2018,1,1), send_in_real_time: true) }

    it "returns true for entries with 'real time' flag enabled" do
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

    it "returns false if there are no broker invoices after the the archive setup's start date" do
      e.broker_invoices.first.update_attributes! invoice_date: Date.new(2017,12,1)
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

    it "FTPs attachment using entry's customer number for file name and destination path" do
      archive_setup = instance_double AttachmentArchiveSetup
      ftp_opts = "ftp opts"
      expect(att).to receive(:bucket).and_return "bucket"
      expect(att).to receive(:path).and_return "path"
      expect(OpenChain::S3).to receive(:download_to_tempfile).with("bucket", "path", {original_filename: "12345_Archive_Packet_201803152030.pdf"}).and_yield archive_setup
      expect(subject).to receive(:connect_vfitrack_net).with("to_ecs/attachment_archive/CUSTNUM").and_return ftp_opts
      expect(subject).to receive(:ftp_file).with(archive_setup, ftp_opts)

      Timecop.freeze(DateTime.new(2018,3,15,20,30)) { subject.ftp_archive att }
    end
  end
end
