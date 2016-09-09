require 'spec_helper'

describe OpenChain::CustomHandler::Vandegrift::KewillEntryDocumentsSender do

  subject { described_class }

  describe "send_s3_document_to_kewill" do 
    let (:downloaded_file) { 
      tf = Tempfile.new ["file", ".txt"]
      tf << "Content"
      tf.flush
      tf.rewind
      allow(tf).to receive(:original_filename).and_return "12345 - CUST.pdf"
      tf
    }
    let (:attachment_type) { AttachmentType.create! name: "Document Type", kewill_document_code: "11111"}
    let (:entry) { Entry.create! customer_number: "CUST", source_system: "Alliance", broker_reference: "12345"}

    after :each do
      downloaded_file.close! unless downloaded_file.closed?
    end

    context "with valid data" do
      before :each do
        attachment_type
        entry
      end

      it "validates path data and ftp's the file" do
        opts = nil
        expect(subject).to receive(:ftp_file) do |file, ftp_options|
          expect(file).to eq downloaded_file
          opts = ftp_options
        end
        
        expect(OpenChain::S3).to receive(:download_to_tempfile).with("bucket", "US Entry Documents/Root/Document Type/12345 - CUST.pdf", version: "version", original_filename: "12345 - CUST.pdf").and_yield downloaded_file
        expect(OpenChain::S3).to receive(:delete).with("bucket", "US Entry Documents/Root/Document Type/12345 - CUST.pdf", "version")

        subject.send_s3_document_to_kewill("bucket", "US Entry Documents/Root/Document Type/12345 - CUST.pdf", "version")

        expect(opts[:remote_file_name]).to eq "I_IE_12345__11111__N_.pdf"
        expect(opts[:server]).to eq "connect.vfitrack.net"
        expect(opts[:folder]).to eq "to_ecs/kewill_imaging"
      end
    end

    it "validates data and emails errors back to file owner" do
      # In this case, we'll have a valid file path, but all other aspects of the data will be invalid
      Attachment.add_original_filename_method downloaded_file, "12345 - CUST.txt"
      expect(OpenChain::S3).to receive(:download_to_tempfile).with("bucket", "US Entry Documents/Root/Document Type/12345 - CUST.txt", version: "version", original_filename: "12345 - CUST.txt").and_yield downloaded_file
      expect(OpenChain::S3).to receive(:metadata).with("owner", "bucket", "US Entry Documents/Root/Document Type/12345 - CUST.txt", "version").and_return "you@there.com"
      expect(OpenChain::S3).to receive(:delete).with("bucket", "US Entry Documents/Root/Document Type/12345 - CUST.txt", "version")

      subject.send_s3_document_to_kewill("bucket", "US Entry Documents/Root/Document Type/12345 - CUST.txt", "version")

      email = ActionMailer::Base.deliveries.first
      expect(email).not_to be_nil
      expect(email.to).to eq ["you@there.com"]
      expect(email.subject).to eq "[VFI Track] Failed to load file 12345 - CUST.txt"
      expect(email.attachments["12345 - CUST.txt"]).not_to be_nil
      expect(email.attachments["12345 - CUST.txt"].read).to eq "Content"
      expect(email.body.raw_source).to include "No Kewill Imaging document code is configured for Document Type."
      expect(email.body.raw_source).to include ERB::Util.html_escape("Kewill Imaging does not accept 'txt' file types.")
      expect(email.body.raw_source).to include "No entry found for File # 12345 under Customer account CUST."
    end

    it "errors if file name is invalid and emails owner" do
      expect(OpenChain::S3).to receive(:download_to_tempfile).with("bucket", "US Entry Documents/Root/Document Type/12345.txt", version: "version", original_filename: "12345.txt").and_yield downloaded_file
      expect(OpenChain::S3).to receive(:metadata).with("owner", "bucket", "US Entry Documents/Root/Document Type/12345.txt", "version").and_return "you@there.com"
      expect(OpenChain::S3).to receive(:delete).with("bucket", "US Entry Documents/Root/Document Type/12345.txt", "version")

     
      subject.send_s3_document_to_kewill("bucket", "US Entry Documents/Root/Document Type/12345.txt", "version")

      email = ActionMailer::Base.deliveries.first
      expect(email).not_to be_nil

      expect(email.body.raw_source).to include ERB::Util.html_escape("Kewill Imaging files must be named with the File #, a hyphen, the file's customer number and then .pdf/.tif.  (ex. '1234 - CUST.pdf')")
    end

    it "uses bug email address to send to if file owner cannot be discovered" do
      Attachment.add_original_filename_method downloaded_file, "12345 - CUST.pdf"
      expect(OpenChain::S3).to receive(:download_to_tempfile).with("bucket", "US Entry Documents/Root/Document Type/12345 - CUST.pdf", version: "version", original_filename: "12345 - CUST.pdf").and_yield downloaded_file
      expect(OpenChain::S3).to receive(:delete).with("bucket", "US Entry Documents/Root/Document Type/12345 - CUST.pdf", "version")
      expect(OpenChain::S3).to receive(:metadata).with("owner", "bucket", "US Entry Documents/Root/Document Type/12345 - CUST.pdf", "version").and_return nil

      subject.send_s3_document_to_kewill("bucket", "US Entry Documents/Root/Document Type/12345 - CUST.pdf", "version")

      email = ActionMailer::Base.deliveries.first
      expect(email).not_to be_nil
      expect(email.to).to eq [OpenMailer::BUG_EMAIL]
    end
  end
end