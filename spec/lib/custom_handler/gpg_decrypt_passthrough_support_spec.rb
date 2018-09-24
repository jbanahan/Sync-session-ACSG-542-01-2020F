require 'spec_helper'

describe OpenChain::CustomHandler::GpgDecryptPassthroughSupport do
  subject do 
    Class.new do 
      include OpenChain::CustomHandler::GpgDecryptPassthroughSupport
    end
  end

  describe "parse_file" do

    let (:log) { InboundFile.new }
    let (:gpg_helper) { 
      gpg = instance_double("OpenChain::GPG")
      allow_any_instance_of(subject).to receive(:gpg_helper).and_return gpg
      gpg
    }

    it "downloads from S3, decrypts file, and yields it" do
      tempfile = double("Tempfile")
      allow(tempfile).to receive(:original_filename).and_return "file.txt.pgp"
      expect(OpenChain::S3).to receive(:download_to_tempfile).with("bucket", "path/to/file.txt.pgp", original_filename: "file.txt.pgp").and_yield tempfile

      expect(gpg_helper).to receive(:decrypt_file) do |source, dest, passphrase|
        expect(dest).to be_a Tempfile
        expect(source).to eq tempfile
        # passphrase is nil unless overridden
        expect(passphrase).to be_nil

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


      expect(gpg_helper).to receive(:decrypt_file)
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
      end.new
    }

    let! (:gpg_helper) { 
      gpg = OpenChain::GPG.new 'spec/fixtures/files/vfitrack-passphraseless.gpg.key', 'spec/fixtures/files/vfitrack-passphraseless.gpg.private.key'
      allow(subject).to receive(:gpg_helper).and_return gpg
      gpg
    }

    it "decrypts file" do
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
      file = File.open('spec/fixtures/files/passphraseless-encrypted.gpg', "rb")    
      allow(file).to receive(:original_filename).and_return "encrypted.txt.pgp"

      filename = nil
      subject.decrypt_file_to_tempfile(file) do |temp|
        filename = temp.original_filename
      end
      expect(filename).to eq "encrypted.txt"
    end

    it "allows for overriding gpg_passphrase method to provide passphrase for encryption" do
      gpg = OpenChain::GPG.new 'spec/fixtures/files/vfitrack.gpg.key', 'spec/fixtures/files/vfitrack.gpg.private.key'
      expect(subject).to receive(:gpg_helper).and_return gpg
      allow(subject).to receive(:gpg_passphrase).and_return 'passphrase'

      file = File.open('spec/fixtures/files/passphrase-encrypted.gpg', "rb")

      output = nil
      subject.decrypt_file_to_tempfile(file) do |temp|
        output = temp.read
      end

      expect(output).to eq IO.binread("spec/fixtures/files/passphrase-cleartext.txt")
    end
  end
end