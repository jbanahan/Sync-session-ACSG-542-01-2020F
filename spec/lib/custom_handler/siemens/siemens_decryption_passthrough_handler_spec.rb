describe OpenChain::CustomHandler::Siemens::SiemensDecryptionPassthroughHandler do

  describe "gpg_helper" do
    it "has the correct key paths" do
      expect(subject.gpg_helper.public_key_path).to eq "config/siemens.asc"
      expect(subject.gpg_helper.private_key_path).to eq "config/vfi-canada.asc"
    end
  end

  describe "gpg_passphrase" do
    it "uses the correct passphrase" do
      expect(subject.gpg_passphrase).to eq "R!ch2805"
    end
  end

  describe "process_from_s3" do
    subject { described_class }

    it "figures out the vendor filetype and calls super" do
      # Just expect this method as a way to know the super version of process_from_s3 was invoked
      expect(subject).to receive(:handle_processing).with("bucket", "VENDOR.txt", {original_filename: "VENDOR.txt"})
      subject.process_from_s3 "bucket", "VENDOR.txt", {original_filename: "VENDOR.txt"}
    end

    it "figures out the product filetype and calls super" do
      # Just expect this method as a way to know the super version of process_from_s3 was invoked
      expect(subject).to receive(:handle_processing).with("bucket", "CAXPR.txt", {original_filename: "CAXPR.txt"})
      subject.process_from_s3 "bucket", "CAXPR.txt", {original_filename: "CAXPR.txt"}
    end

    it "returns quickly if unidentified filetype is used" do
      expect(subject).not_to receive(:handle_processing)

      expect(subject.process_from_s3 "bucket", "file.txt").to be_nil
    end
  end

  describe "ftp_credentials" do
    before :each do
      expect(subject).to receive(:inbound_file).and_return log
    end

    context "with vendor files" do
      let (:log) { InboundFile.new file_name: "VENDOR.txt" }

      it "uses correct credentials for vendor files" do
        expect(subject).to receive(:connect_vfitrack_net).with("to_ecs/siemens/vendors")
        subject.ftp_credentials
      end
    end

    context "with vendor files" do
      let (:log) { InboundFile.new file_name: "CAXPR.txt" }

      it "uses correct credentials for product files" do
        expect(subject).to receive(:connect_vfitrack_net).with("to_ecs/siemens/parts")
        subject.ftp_credentials
      end
    end

    context "with invalid filetype" do
      let (:log) { InboundFile.new file_name: "whatever.txt" }

      it "raises an error on unidentified parts" do
        expect {subject.ftp_credentials}.to raise_error LoggedParserFatalError, "Unexpected Siemens filetype of '' found."
        expect(log.get_process_status_from_messages).to eq InboundFile::PROCESS_STATUS_ERROR
      end
    end
  end
end