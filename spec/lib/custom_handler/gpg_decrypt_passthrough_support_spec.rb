describe OpenChain::CustomHandler::GpgDecryptPassthroughSupport do
  subject do
    Class.new do
      include OpenChain::CustomHandler::GpgDecryptPassthroughSupport

      def gpg_secrets_key
        raise "Mock me"
      end
    end
  end

  describe "parse_file" do

    let (:log) { InboundFile.new }

    it "downloads from S3, decrypts file, and yields it" do
      tempfile = double("Tempfile")
      allow(tempfile).to receive(:original_filename).and_return "file.txt.pgp"
      expect(OpenChain::S3).to receive(:download_to_tempfile).with("bucket", "path/to/file.txt.pgp", original_filename: "file.txt.pgp").and_yield tempfile
      expect_any_instance_of(subject).to receive(:gpg_secrets_key).and_return "secrets"

      expect(OpenChain::GPG).to receive(:decrypt_io) do |source, dest, secrets_key|
        expect(secrets_key).to eq "secrets"

        expect(dest).to be_a Tempfile
        expect(source).to eq tempfile

        # Just write some data to the dest file so we can make sure the correct data is being passed around.
        dest << "Testing"
        dest.flush

        dest.rewind
      end

      ftp_data = nil
      ftp_filename = nil
      expect_any_instance_of(subject).to receive(:ftp_file) do |inst, f|
        ftp_data = f.read
        ftp_filename = f.original_filename
      end

      subject.parse_file(nil, log, {bucket: "bucket", key: "path/to/file.txt.pgp"})
      expect(ftp_data).to eq "Testing"
      expect(ftp_filename).to eq "file.txt"
    end

    it "uses original_filename if given for decrypted filename" do
      tempfile = double("Tempfile")
      allow(tempfile).to receive(:original_filename).and_return "file.txt.pgp"
      expect(OpenChain::S3).to receive(:download_to_tempfile).with("bucket", "path/to/file.txt.pgp", original_filename: "given_file.txt.pgp").and_yield tempfile

      expect_any_instance_of(subject).to receive(:gpg_secrets_key).and_return "secrets"
      expect(OpenChain::GPG).to receive(:decrypt_io)
      expect_any_instance_of(subject).to receive(:ftp_file)

      subject.parse_file(nil, log, {bucket: "bucket", key: "path/to/file.txt.pgp", original_filename: "given_file.txt.pgp"})
    end

    it "errors if bucket is not provided" do
      expect { subject.parse_file nil, log, {key: "test"} }.to raise_error LoggedParserFatalError, "All invocations of this parser must include :bucket and :key options."
    end

    it "errors if key is not provided" do
      expect { subject.parse_file nil, log, {bucket: "test"} }.to raise_error LoggedParserFatalError, "All invocations of this parser must include :bucket and :key options."
    end
  end

  describe "decrypt_file_to_tempfile" do
    subject {
      Class.new do
        include OpenChain::CustomHandler::GpgDecryptPassthroughSupport

        def gpg_secrets_key
          "passthrough_test"
        end
      end.new
    }

    let (:secrets) {
      {
        "gpg" => {
          "passthrough_test" => {
            "private_key_path" => 'spec/fixtures/files/vfitrack-passphraseless.gpg.private.key',
            "public_key_path" => 'spec/fixtures/files/vfitrack-passphraseless.gpg.key'
          }
        }
      }
    }

    it "decrypts file" do
      expect(MasterSetup).to receive(:secrets).and_return secrets

      file = File.open('spec/fixtures/files/passphraseless-encrypted.gpg', "rb")

      output = nil
      filename = nil
      subject.decrypt_file_to_tempfile(file) do |temp|
        output = temp.read
        filename = temp.original_filename
      end

      expect(output).to eq IO.binread("spec/fixtures/files/passphraseless-cleartext.txt")
      expect(filename).to eq "passphraseless-encrypted"
    end

    it "pulls filename from original_filename method and strips pgp from filename" do
      expect(MasterSetup).to receive(:secrets).and_return secrets

      file = File.open('spec/fixtures/files/passphraseless-encrypted.gpg', "rb")
      Attachment.add_original_filename_method(file, "encrypted.txt.pgp")

      filename = nil
      subject.decrypt_file_to_tempfile(file) do |temp|
        filename = temp.original_filename
      end
      expect(filename).to eq "encrypted.txt"
    end
  end
end