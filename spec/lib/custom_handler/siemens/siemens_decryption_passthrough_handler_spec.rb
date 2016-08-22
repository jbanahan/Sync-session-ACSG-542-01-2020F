require 'spec_helper'

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
    it "figures out the vendor filetype and calls super" do
      # Just expect this method as a way to know the super version of process_from_s3 was invoked
      expect(OpenChain::S3).to receive(:download_to_tempfile).with "bucket", "VENDOR.txt", instance_of(Hash)

      subject.process_from_s3 "bucket", "VENDOR.txt"
      expect(subject.filetype).to eq :vendor
    end

    it "passes original_filename to super" do
      # Just expect this method as a way to know the super version of process_from_s3 was invoked
      expect(OpenChain::S3).to receive(:download_to_tempfile).with "bucket", "s3/path/to/file.txt", original_filename: 'VENDOR.txt'
      subject.process_from_s3 "bucket", "s3/path/to/file.txt", original_filename: 'VENDOR.txt'
      expect(subject.filetype).to eq :vendor
    end

    it "figures out the product filetype and calls super" do
      # Just expect this method as a way to know the super version of process_from_s3 was invoked
      expect(OpenChain::S3).to receive(:download_to_tempfile).with "bucket", "CAXPR.txt", instance_of(Hash)

      subject.process_from_s3 "bucket", "CAXPR.txt"
      expect(subject.filetype).to eq :product
    end

    it "returns quickly if unidentified filetype is used" do
      expect(OpenChain::S3).not_to receive(:download_to_tempfile)

      expect(subject.process_from_s3 "bucket", "file.txt").to be_nil
      expect(subject.filetype).to be_nil
    end
  end

  describe "ftp_credentials" do 
    context "with vendor files" do
      before :each do
        expect(OpenChain::S3).to receive(:download_to_tempfile)
        subject.process_from_s3 'bucket', 'VENDOR.txt'
      end

      it "uses correct credentials for vendor files" do
        expect(subject).to receive(:fenixapp_vfitrack_net).with("Incoming/Vendors/SIEMENS/Incoming")
        subject.ftp_credentials
      end
    end

    context "with product files" do
      before :each do
        expect(OpenChain::S3).to receive(:download_to_tempfile)
        subject.process_from_s3 'bucket', 'CAXPR.txt'
      end

      it "uses correct credentials for product files" do
        expect(subject).to receive(:fenixapp_vfitrack_net).with("Incoming/Parts/SIEMENS/Incoming")
        subject.ftp_credentials
      end
    end
    
    it "raises an error on unidentified parts" do
      # the file type is not identified till after process from s3 is run...so by defaul it's blank
      # and will raise
      expect {subject.ftp_credentials}.to raise_error "Unexpected Siemens filetype of '' found."
    end
  end
end