require 'spec_helper'

describe OpenChain::CustomHandler::Vandegrift::KewillEntryDocumentsSender do

  subject { described_class }

  describe "send_google_drive_document_to_kewill" do
    let (:google_drive) { double("OpenChain::GoogleDrive") }
    let (:downloaded_file) { 
      tf = Tempfile.new ["file", ".txt"]
      tf << "Content"
      tf.flush
      tf.rewind
      tf
    }
    let (:attachment_type) { AttachmentType.create! name: "Document Type", kewill_document_code: "11111"}
    let (:entry) { Entry.create! customer_number: "CUST", source_system: "Alliance", broker_reference: "12345"}

    before :each do
      allow(subject).to receive(:drive_client).and_return google_drive
    end

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
        
        expect(google_drive).to receive(:download_to_tempfile).with("me@there.com", "US Entry Documents/Root/Document Type/12345 - CUST.pdf").and_yield downloaded_file
        expect(google_drive).to receive(:remove_file_from_folder).with("me@there.com", "US Entry Documents/Root/Document Type/12345 - CUST.pdf")

        subject.send_google_drive_document_to_kewill("me@there.com", "Root/Document Type/12345 - CUST.pdf")

        expect(opts[:remote_file_name]).to eq "I_IE_12345__11111__N_.pdf"
        expect(opts[:server]).to eq "connect.vfitrack.net"
        expect(opts[:folder]).to eq "to_ecs/kewill_imaging"
      end
    end

    it "validates data and emails errors back to Drive file owner" do
      # In this case, we'll have a valid file path, but all other aspects of the data will be invalid
      Attachment.add_original_filename_method downloaded_file, "12345 - CUST.txt"
      expect(google_drive).to receive(:download_to_tempfile).with("me@there.com", "US Entry Documents/Root/Document Type/12345 - CUST.txt").and_yield downloaded_file
      expect(google_drive).to receive(:get_file_owner_email).with("me@there.com", "US Entry Documents/Root/Document Type/12345 - CUST.txt").and_return "you@there.com"
      expect(google_drive).to receive(:remove_file_from_folder).with("me@there.com", "US Entry Documents/Root/Document Type/12345 - CUST.txt")

      subject.send_google_drive_document_to_kewill("me@there.com", "Root/Document Type/12345 - CUST.txt")

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
      expect(google_drive).to receive(:download_to_tempfile).with("me@there.com", "US Entry Documents/Root/Document Type/12345.txt").and_yield downloaded_file
      expect(google_drive).to receive(:get_file_owner_email).with("me@there.com", "US Entry Documents/Root/Document Type/12345.txt").and_return "you@there.com"
      expect(google_drive).to receive(:remove_file_from_folder).with("me@there.com", "US Entry Documents/Root/Document Type/12345.txt")
     
      subject.send_google_drive_document_to_kewill("me@there.com", "Root/Document Type/12345.txt")

      email = ActionMailer::Base.deliveries.first
      expect(email).not_to be_nil

      expect(email.body.raw_source).to include ERB::Util.html_escape("Kewill Imaging files must be named with the File #, a hyphen, the file's customer number and then .pdf/.tif.  (ex. '1234 - CUST.pdf')")
    end

    it "uses bug email address to send to if file owner cannot be discovered" do
      expect(google_drive).to receive(:download_to_tempfile).with("me@there.com", "US Entry Documents/Root/Document Type/12345.txt").and_yield downloaded_file
      expect(google_drive).to receive(:get_file_owner_email).with("me@there.com", "US Entry Documents/Root/Document Type/12345.txt").and_return nil
      expect(google_drive).to receive(:remove_file_from_folder).with("me@there.com", "US Entry Documents/Root/Document Type/12345.txt")

      subject.send_google_drive_document_to_kewill("me@there.com", "Root/Document Type/12345.txt")

      email = ActionMailer::Base.deliveries.first
      expect(email).not_to be_nil
      expect(email.to).to eq [OpenMailer::BUG_EMAIL]
    end
  end
end