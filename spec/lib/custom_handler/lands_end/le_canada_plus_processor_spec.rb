require 'spec_helper'

describe OpenChain::CustomHandler::LandsEnd::LeCanadaPlusProcessor do
  describe "process_from_s3" do
    it "retrieves file from S3 and passes it to ZIP handler" do
      tempfile = double("tempfile")
      OpenChain::S3.should_receive(:download_to_tempfile).with("bucket", "key").and_yield tempfile
      described_class.should_receive(:process_zip).with tempfile
      described_class.process_from_s3 "bucket", "key"
    end
  end

  describe "process_zip" do
    it "extracts files from ZIP, creates upload file" do      
      File.open("#{Rails.root}/spec/fixtures/files/lands_end_canada_plus.zip") do |f|
        described_class.process_zip f
      end
      upload = DrawbackUploadFile.first
  
      expect(DrawbackUploadFile.count).to eq 1
      expect(upload.processor).to eq "lands_end_exports"
      expect(upload.start_at).not_to be_nil
      expect(upload.attachment.attached_file_name).to eq "b3.txt"
    end

    it "skips files with extension other than 'txt'" do
      File.open("#{Rails.root}/spec/fixtures/files/lands_end_canada_plus_2.zip") do |f|
        described_class.process_zip f
      end

      expect(DrawbackUploadFile.count).to eq 0
    end
  end
end