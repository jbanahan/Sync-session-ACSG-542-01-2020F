require 'spec_helper'

describe OpenChain::CustomHandler::GpgDecryptPassthroughSupport do
  subject do 
    Class.new do 
      include OpenChain::CustomHandler::GpgDecryptPassthroughSupport
    end.new
  end

  describe "process_from_s3" do

    before :each do
      @gpg_helper = double("OpenChain::GPG")
      subject.stub(:gpg_helper).and_return @gpg_helper
    end

    it "downloads from S3, decrypts file, and yields it" do
      tempfile = double("Tempfile")
      tempfile.stub(:original_filename).and_return "file.txt.pgp"
      OpenChain::S3.should_receive(:download_to_tempfile).with("bucket", "path/to/file.txt.pgp", original_filename: "file.txt.pgp").and_yield tempfile

      @gpg_helper.should_receive(:decrypt_file) do |source, dest, passphrase|
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
      subject.should_receive(:ftp_file) do |f|
        ftp_data = f.read
        ftp_filename = f.original_filename
      end

      subject.process_from_s3 "bucket", "path/to/file.txt.pgp"
      expect(ftp_data).to eq "Testing"
      expect(ftp_filename).to eq "file.txt"
    end
  end

  describe "decrypt_file_to_tempfile" do
    before :each do
      @gpg_helper = OpenChain::GPG.new 'spec/fixtures/files/vfitrack-passphraseless.gpg.key', 'spec/fixtures/files/vfitrack-passphraseless.gpg.private.key'
      subject.stub(:gpg_helper).and_return @gpg_helper
    end

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
      file.stub(:original_filename).and_return "encrypted.txt.pgp"

      filename = nil
      subject.decrypt_file_to_tempfile(file) do |temp|
        filename = temp.original_filename
      end
      expect(filename).to eq "encrypted.txt"
    end

    it "allows for overriding gpg_passphrase method to provide passphrase for encryption" do
      @gpg_helper = OpenChain::GPG.new 'spec/fixtures/files/vfitrack.gpg.key', 'spec/fixtures/files/vfitrack.gpg.private.key'
      subject.stub(:gpg_helper).and_return @gpg_helper
      subject.stub(:gpg_passphrase).and_return 'passphrase'

      file = File.open('spec/fixtures/files/passphrase-encrypted.gpg', "rb")

      output = nil
      subject.decrypt_file_to_tempfile(file) do |temp|
        output = temp.read
      end

      expect(output).to eq IO.binread("spec/fixtures/files/passphrase-cleartext.txt")
    end
  end
end