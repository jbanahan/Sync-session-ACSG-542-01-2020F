describe OpenChain::CustomHandler::Vandegrift::KewillEntryDocumentsSender do

  subject { described_class }

  describe "send_s3_document_to_kewill" do
    let (:downloaded_file) {
      tf = Tempfile.new ["file", ".txt"]
      tf << "Content"
      tf.flush
      tf.rewind
      Attachment.add_original_filename_method(tf, "12345 - CUST.pdf")
      allow(tf).to receive(:original_filename).and_return "12345 - CUST.pdf"
      tf
    }
    let (:attachment_type) { AttachmentType.create! name: "Document Type", kewill_document_code: "11111", kewill_attachment_type: "Document Type"}
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

        now = Time.zone.now
        Timecop.freeze(now) do
          subject.send_s3_document_to_kewill("bucket", "US Entry Documents/Root/Document Type/12345 - CUST.pdf", "version")
        end

        expect(opts[:remote_file_name]).to eq "I_IE_12345__11111_1_N_#{now.to_f.to_s.gsub(".", "-")}.pdf"
        expect(opts[:server]).to eq "connect.vfitrack.net"
        expect(opts[:folder]).to eq "to_ecs/kewill_imaging"

        # Make sure a key json item was created...
        item = KeyJsonItem.entry_document_counts("12345").first
        expect(item.data).to eq({"11111"=> 1})
      end

      it "uses next suffix value for multiple documents" do
        KeyJsonItem.entry_document_counts("12345").create! json_data: {"11111"=> 1}.to_json

        opts = nil
        expect(subject).to receive(:ftp_file) do |file, ftp_options|
          expect(file).to eq downloaded_file
          opts = ftp_options
        end

        expect(OpenChain::S3).to receive(:download_to_tempfile).with("bucket", "US Entry Documents/Root/Document Type/12345 - CUST.pdf", version: "version", original_filename: "12345 - CUST.pdf").and_yield downloaded_file
        expect(OpenChain::S3).to receive(:delete).with("bucket", "US Entry Documents/Root/Document Type/12345 - CUST.pdf", "version")

        now = Time.zone.now
        Timecop.freeze(now) do
          subject.send_s3_document_to_kewill("bucket", "US Entry Documents/Root/Document Type/12345 - CUST.pdf", "version")
        end

        expect(opts[:remote_file_name]).to eq "I_IE_12345__11111_2_N_#{now.to_f.to_s.gsub(".", "-")}.pdf"
        item = KeyJsonItem.entry_document_counts("12345").first
        expect(item.data).to eq({"11111"=> 2})
      end

      it "does not use a suffix lower than one already attached to an entry" do
        entry.attachments.create! alliance_suffix: "005", attachment_type: "Document Type"

        opts = nil
        expect(subject).to receive(:ftp_file) do |file, ftp_options|
          expect(file).to eq downloaded_file
          opts = ftp_options
        end

        expect(OpenChain::S3).to receive(:download_to_tempfile).with("bucket", "US Entry Documents/Root/Document Type/12345 - CUST.pdf", version: "version", original_filename: "12345 - CUST.pdf").and_yield downloaded_file
        expect(OpenChain::S3).to receive(:delete).with("bucket", "US Entry Documents/Root/Document Type/12345 - CUST.pdf", "version")

        now = Time.zone.now
        Timecop.freeze(now) do
          subject.send_s3_document_to_kewill("bucket", "US Entry Documents/Root/Document Type/12345 - CUST.pdf", "version")
        end

        expect(opts[:remote_file_name]).to eq "I_IE_12345__11111_6_N_#{now.to_f.to_s.gsub(".", "-")}.pdf"
        item = KeyJsonItem.entry_document_counts("12345").first
        expect(item.data).to eq({"11111"=> 6})
      end

      it "allows user to add random info after the customer number" do
        allow(downloaded_file).to receive(:original_filename).and_return "12345 - CUST Some Random Info (1).pdf"
        opts = nil
        expect(subject).to receive(:ftp_file) do |file, ftp_options|
          expect(file).to eq downloaded_file
          opts = ftp_options
        end

        expect(OpenChain::S3).to receive(:download_to_tempfile).with("bucket", "US Entry Documents/Root/Document Type/12345 - CUST Some Random Info (1).pdf", version: "version", original_filename: "12345 - CUST Some Random Info (1).pdf").and_yield downloaded_file
        expect(OpenChain::S3).to receive(:delete).with("bucket", "US Entry Documents/Root/Document Type/12345 - CUST Some Random Info (1).pdf", "version")

        now = Time.zone.now
        Timecop.freeze(now) do
          subject.send_s3_document_to_kewill("bucket", "US Entry Documents/Root/Document Type/12345 - CUST Some Random Info (1).pdf", "version")
        end

        expect(opts[:remote_file_name]).to eq "I_IE_12345__11111_1_N_#{now.to_f.to_s.gsub(".", "-")}.pdf"
        expect(opts[:server]).to eq "connect.vfitrack.net"
        expect(opts[:folder]).to eq "to_ecs/kewill_imaging"
      end

      it "does not use a suffix for document types that don't allow multiple docs" do
        attachment_type.update_attributes! disable_multiple_kewill_docs: true

        opts = nil
        expect(subject).to receive(:ftp_file) do |file, ftp_options|
          expect(file).to eq downloaded_file
          opts = ftp_options
        end

        expect(OpenChain::S3).to receive(:download_to_tempfile).with("bucket", "US Entry Documents/Root/Document Type/12345 - CUST.pdf", version: "version", original_filename: "12345 - CUST.pdf").and_yield downloaded_file
        expect(OpenChain::S3).to receive(:delete).with("bucket", "US Entry Documents/Root/Document Type/12345 - CUST.pdf", "version")

        now = Time.zone.now
        Timecop.freeze(now) do
          subject.send_s3_document_to_kewill("bucket", "US Entry Documents/Root/Document Type/12345 - CUST.pdf", "version")
        end

        expect(opts[:remote_file_name]).to eq "I_IE_12345__11111__N_#{now.to_f.to_s.gsub(".", "-")}.pdf"
        expect(opts[:server]).to eq "connect.vfitrack.net"
        expect(opts[:folder]).to eq "to_ecs/kewill_imaging"

        expect(KeyJsonItem.entry_document_counts("12345").first).to be_nil
      end

      it "allows user to duplicate the filename extension" do
        expect(subject).to receive(:ftp_file)

        expect(OpenChain::S3).to receive(:download_to_tempfile).with("bucket", "US Entry Documents/Root/Document Type/12345 - CUST.pdf.pdf", version: "version", original_filename: "12345 - CUST.pdf.pdf").and_yield downloaded_file
        expect(OpenChain::S3).to receive(:delete).with("bucket", "US Entry Documents/Root/Document Type/12345 - CUST.pdf.pdf", "version")

        subject.send_s3_document_to_kewill("bucket", "US Entry Documents/Root/Document Type/12345 - CUST.pdf.pdf", "version")
      end


      it "errors if file is over 70 MB" do
        expect(downloaded_file).to receive(:size).and_return 71.megabytes

        expect(OpenChain::S3).to receive(:download_to_tempfile).with("bucket", "US Entry Documents/Root/Document Type/12345 - CUST.txt", version: "version", original_filename: "12345 - CUST.txt").and_yield downloaded_file
        expect(OpenChain::S3).to receive(:delete).with("bucket", "US Entry Documents/Root/Document Type/12345 - CUST.txt", "version")
        expect(OpenChain::S3).to receive(:metadata).with("owner", "bucket", "US Entry Documents/Root/Document Type/12345 - CUST.txt", "version").and_return "you@there.com"

        subject.send_s3_document_to_kewill("bucket", "US Entry Documents/Root/Document Type/12345 - CUST.txt", "version")

        email = ActionMailer::Base.deliveries.first
        expect(email).not_to be_nil

        expect(email.body.raw_source).to include ERB::Util.html_escape("File is larger than 70 Megabytes.  Please forward this error to IT Support for help loading this file.")
        # Make sure we're not attaching 70+ megabyte files to emails.
        expect(email.attachments.size).to eq 0
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
      expect(email.body.raw_source).to include ERB::Util.html_escape("No Kewill Imaging document code is configured for 'Document Type'.")
      expect(email.body.raw_source).to include ERB::Util.html_escape("Kewill Imaging does not accept 'txt' file types.")
      expect(email.body.raw_source).to include ERB::Util.html_escape("No entry found for File # '12345' under Customer account 'CUST'.")
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

    it "handles no such key error as a no-op" do
      expect(OpenChain::S3).to receive(:download_to_tempfile).and_raise OpenChain::S3::NoSuchKeyError
      expect(subject.send_s3_document_to_kewill("bucket", "US Entry Documents/Root/Document Type/12345 - CUST.pdf", "version")).to be_nil
    end

    it "errors if attachment type is missing kewill document cross-reference" do
      attachment_type.update_attributes! kewill_attachment_type: ""
      entry

      expect(OpenChain::S3).to receive(:download_to_tempfile).with("bucket", "US Entry Documents/Root/Document Type/12345 - CUST.txt", version: "version", original_filename: "12345 - CUST.txt").and_yield downloaded_file
      expect(OpenChain::S3).to receive(:metadata).with("owner", "bucket", "US Entry Documents/Root/Document Type/12345 - CUST.txt", "version").and_return "you@there.com"
      expect(OpenChain::S3).to receive(:delete).with("bucket", "US Entry Documents/Root/Document Type/12345 - CUST.txt", "version")

      subject.send_s3_document_to_kewill("bucket", "US Entry Documents/Root/Document Type/12345 - CUST.txt", "version")

      email = ActionMailer::Base.deliveries.first
      expect(email).not_to be_nil
      expect(email.body.raw_source).to include ERB::Util.html_escape("Attachment Type 'Document Type' is missing a Kewill Attachment Type cross-reference value.  Please forward this error to IT Support.")
    end
  end

  describe "run_schedulable" do

    it "monitors given bucket and sends docs to kewill" do
      expect(OpenChain::S3).to receive(:each_file_in_bucket).with("testing", list_versions: true).and_yield "key", "version"
      expect(subject).to receive(:delay).and_return subject
      expect(subject).to receive(:send_s3_document_to_kewill).with("testing", "key", "version")

      subject.run_schedulable({"bucket" => "testing"})
    end

    it "monitors multiple buckets if supplied" do
      expect(OpenChain::S3).to receive(:each_file_in_bucket).with("test", list_versions: true).and_yield "key", "version"
      expect(OpenChain::S3).to receive(:each_file_in_bucket).with("test2", list_versions: true).and_yield "key2", "version2"
      expect(subject).to receive(:delay).at_least(:once).and_return subject
      expect(subject).to receive(:send_s3_document_to_kewill).with("test", "key", "version")
      expect(subject).to receive(:send_s3_document_to_kewill).with("test2", "key2", "version2")

      subject.run_schedulable({"bucket" => ["test", "test2"]})
    end

    it "raises an error if bucket option is not set" do
      expect { subject.run_schedulable }.to raise_error StandardError, "A 'bucket' option value must be set."
    end
  end

  describe "send_entry_packet_to_s3_imaging" do
    let(:entry) { Entry.new(broker_reference: "51315", customer_number: "CUSTO") }
    let(:master_setup) { stub_master_setup }
    let(:file) { instance_double("File") }

    it "sends a file to the s3 imaging test bucket" do
      expect(master_setup).to receive(:production?).and_return false
      expect(OpenChain::S3).to receive(:upload_file).with("kewill-imaging-test",
                                                          "US Entry Documents/Entry Packet/51315-CUSTO.pdf",
                                                          file).and_return "success"

      expect(described_class.send_entry_packet_to_s3(entry, file)).to eq "success"
    end

    it "sends a file to the s3 imaging production bucket" do
      expect(master_setup).to receive(:production?).and_return true
      expect(OpenChain::S3).to receive(:upload_file).with("kewill-imaging",
                                                          "US Entry Documents/Entry Packet/51315-CUSTO.pdf",
                                                          file).and_return "success"

      expect(described_class.send_entry_packet_to_s3(entry, file)).to eq "success"
    end
  end
end