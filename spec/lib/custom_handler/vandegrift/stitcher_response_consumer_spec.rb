describe OpenChain::CustomHandler::Vandegrift::StitcherResponseConsumer do

  subject { described_class }

  describe "process_entry_stitch_response" do
    let (:entry) do
      FactoryBot(:entry, entry_number: "1234567890")
    end

    let (:a1) do
      entry.attachments.create! attached_file_name: "test.pdf", attachment_type: Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE, created_at: (Time.zone.now - 1.day)
    end

    let (:stitch_response) do
      {
        'stitch_response' => {
          'reference_info' => {
            'key' => "Entry-#{entry.id}",
            'time' => Time.now.iso8601
          },
          'destination_file' => {'path' => '/bucket/path/to/file.pdf', 'service' => 's3'}
        }
      }
    end

    let (:tempfile) do
      Tempfile.new ['stitch_response', '.pdf']
    end

    after do
      tempfile.close!
    end

    it "reads a stitch response and updates an entry's attachments with an archive packet" do
      a1.destroy
      entry.reload
      now = Time.zone.parse("2018-08-01 12:00")
      expect(OpenChain::S3).to receive(:download_to_tempfile).with('bucket', 'path/to/file.pdf').and_yield tempfile
      expect(OpenChain::S3).to receive(:delete).with('bucket', 'path/to/file.pdf')
      expect_any_instance_of(Entry).to receive(:create_snapshot).with(User.integration, nil, "Archive Packet") do |val|
        expect(val.id).to eq entry.id
      end
      expect_any_instance_of(Attachment).to receive(:skip_virus_scan=).with(true)
      Timecop.freeze(now) do
        expect(subject.process_stitch_response(stitch_response)).to eq true
      end

      entry.reload
      expect(entry.attachments.size).to eq(1)
      expect(entry.attachments.first.attachment_type).to eq Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE
      expect(entry.attachments.first.attached_file_name).to eq "#{entry.entry_number}.pdf"
      expect(entry.attachments.first.created_at).to eq Time.iso8601(stitch_response['stitch_response']['reference_info']['time'])
      expect(entry.updated_at).to eq now
    end

    it "does not add new archive if an existing archive is newer" do
      a1.update_column :created_at, (Time.zone.now + 1.day) # rubocop:disable Rails/SkipsModelValidations

      expect(OpenChain::S3).to receive(:download_to_tempfile).with('bucket', 'path/to/file.pdf').and_yield tempfile
      expect(OpenChain::S3).to receive(:delete).with('bucket', 'path/to/file.pdf')
      expect_any_instance_of(Entry).not_to receive(:create_snapshot)

      expect(subject.process_stitch_response(stitch_response)).to eq true

      entry.reload
      expect(entry.attachments.size).to eq(1)
      expect(entry.attachments.first).to eq a1
    end

    it "handles if the stitch request entity isn't found" do
      entry.destroy
      expect(OpenChain::S3).not_to receive(:download_to_tempfile)
      expect(OpenChain::S3).to receive(:delete).with('bucket', 'path/to/file.pdf')
      subject.process_stitch_response stitch_response
    end

    it "logs an error if the response has an error message" do
      stitch_response['stitch_response']['errors'] = [{'message' => 'This is an error'}]
      expect { subject.process_stitch_response stitch_response }.to change(ErrorLogEntry, :count).by(1)
    end

    it "swallows specific error response for EOFException" do
      error = <<~ERR
        A pdftk error occurred while stitching together the paths ["file", "file2"]: Unhandled Java Exception in create_output():
        java.io.EOFException
           at pdftk.com.lowagie.text.pdf.RandomAccessFileOrArray.readFully(pdftk)
           at pdftk.com.lowagie.text.pdf.RandomAccessFileOrArray.readFully(pdftk)
           at pdftk.com.lowagie.text.pdf.PdfReader.getStreamBytesRaw(pdftk)
           at pdftk.com.lowagie.text.pdf.PdfReader.getStreamBytesRaw(pdftk)
      ERR
      stitch_response['stitch_response']['errors'] = [{'message' => error}]

      expect do
        expect(subject.process_stitch_response(stitch_response)).to be_nil
      end.not_to change(ErrorLogEntry, :count)
    end

    it "swallows specific error response for ClassCastException" do
      error = <<~ERR
        A pdftk error occurred while stitching together the paths ["file", "file2"]: Unhandled Java Exception in create_output():
        java.lang.ClassCastException: pdftk.com.lowagie.text.pdf.PdfNull cannot be cast to pdftk.com.lowagie.text.pdf.PdfArray
           at pdftk.com.lowagie.text.pdf.PdfCopy.addPage(pdftk)
      ERR
      stitch_response['stitch_response']['errors'] = [{'message' => error}]

      expect do
        expect(subject.process_stitch_response(stitch_response)).to be_nil
      end.not_to change(ErrorLogEntry, :count)
    end

    it "swallows specific error response for missing file error" do
      stitch_response['stitch_response']['errors'] = [{'message' => "THE SPECIFIED KEY DOES NOT EXIST"}]

      expect do
        expect(subject.process_stitch_response(stitch_response)).to be_nil
      end.not_to change(ErrorLogEntry, :count)
    end
  end

  describe "run_schedulable" do
    let! (:ms) { stub_master_setup }

    it "implements SchedulableJob interface" do
      expect(ms).to receive(:custom_feature?).with("Document Stitching").and_return true
      expect(subject).to receive(:delay).and_return subject
      expect(subject).to receive(:consume_stitch_responses)

      subject.run_schedulable
    end

    it "does not call consume_stitch_responses if custom feature is not enabled" do
      expect(ms).to receive(:custom_feature?).with("Document Stitching").and_return false
      expect(subject).not_to receive(:delay)
      expect(subject).not_to receive(:consume_stitch_responses)

      subject.run_schedulable
    end
  end

  describe "consume_stitch_responses" do
    let (:message_hash) { {'stitch_response' => "response"} }
    let (:message_attributes) { instance_double(OpenChain::SQS::SqsMessageAttributes) }
    let (:sqs_queue) { "https://queue" }

    before do
      allow(subject).to receive(:response_queue).and_return sqs_queue
    end

    it "passes message to process_stitch_response" do
      expect(subject).to receive(:process_stitch_response).with message_hash
      expect(OpenChain::SQS).to receive(:poll).with(sqs_queue, include_attributes: true).and_yield(message_hash, message_attributes)
      subject.consume_stitch_responses
    end

    it "throws 'skip_delete' unless receive count is > 10" do
      expect(OpenChain::SQS).to receive(:poll).with(sqs_queue, include_attributes: true).and_yield(message_hash, message_attributes)
      expect(message_attributes).to receive(:approximate_receive_count).and_return 10
      expect(subject).to receive(:process_stitch_response).and_raise OpenChain::S3::NoSuchKeyError
      expect { subject.consume_stitch_responses }.to throw_symbol :skip_delete
    end

    it "swallows NoSuchKeyError if receive count is > 10" do
      expect(OpenChain::SQS).to receive(:poll).with(sqs_queue, include_attributes: true).and_yield(message_hash, message_attributes)
      expect(message_attributes).to receive(:approximate_receive_count).and_return 11
      expect(subject).to receive(:process_stitch_response).and_raise OpenChain::S3::NoSuchKeyError
      subject.consume_stitch_responses
    end
  end

end