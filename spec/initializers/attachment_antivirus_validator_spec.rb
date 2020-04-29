describe Paperclip::Validators::AttachmentAntiVirusValidator do

  describe "validate_each" do
    subject { described_class.new({attributes: {anti_virus: true}}) }

    let (:record) { instance_double(Attachment) }
    let (:paperclip_attachment) { instance_double(Paperclip::Attachment) }
    let (:io_file) { instance_double(Paperclip::FileAdapter) }
    let (:tempfile) { instance_double(Tempfile) }

    it "uses anti-virus registry to scan file" do
      expect(record).to receive(:attached).and_return paperclip_attachment
      expect(paperclip_attachment).to receive(:file?).and_return true
      expect(paperclip_attachment).to receive(:staged?).and_return true
      expect(Paperclip.io_adapters).to receive(:for).with(paperclip_attachment).and_return io_file
      expect(io_file).to receive(:path).and_return "/path/to/file.txt"
      allow(io_file).to receive(:tempfile).and_return tempfile
      expect(tempfile).to receive(:close).with(true)

      expect(OpenChain::AntiVirus::AntiVirusRegistry).to receive(:safe?).with("/path/to/file.txt").and_return true

      subject.validate_each record, "attached", paperclip_attachment
    end

    it "logs an error if virus scan finds a virus" do
      expect(record).to receive(:attached).and_return paperclip_attachment
      expect(paperclip_attachment).to receive(:file?).and_return true
      expect(paperclip_attachment).to receive(:staged?).and_return true
      expect(Paperclip.io_adapters).to receive(:for).with(paperclip_attachment).and_return io_file
      expect(io_file).to receive(:path).and_return "/path/to/file.txt"
      allow(io_file).to receive(:tempfile).and_return tempfile
      expect(tempfile).to receive(:close).with(true)

      expect(OpenChain::AntiVirus::AntiVirusRegistry).to receive(:safe?).with("/path/to/file.txt").and_return false
      errors = {"attached" => [] }
      expect(record).to receive(:errors).and_return(errors)
      expect(paperclip_attachment).to receive(:original_filename).and_return "file.txt"

      subject.validate_each record, "attached", paperclip_attachment
      expect(errors).to eq({"attached" => ["File 'file.txt' has been flagged as having a virus."]})
    end

    it "does nothing if record indicates no virus scan" do
      expect(record).to receive(:skip_virus_scan).and_return true
      subject.validate_each record, "attached", paperclip_attachment
    end

    it "does nothing if no file is present" do
      expect(record).to receive(:attached).and_return paperclip_attachment
      expect(paperclip_attachment).to receive(:file?).and_return false

      subject.validate_each record, "attached", paperclip_attachment
    end

    it "does nothing if the file is not staged" do
      expect(record).to receive(:attached).and_return paperclip_attachment
      expect(paperclip_attachment).to receive(:file?).and_return true
       expect(paperclip_attachment).to receive(:staged?).and_return false

      subject.validate_each record, "attached", paperclip_attachment
    end
  end
end