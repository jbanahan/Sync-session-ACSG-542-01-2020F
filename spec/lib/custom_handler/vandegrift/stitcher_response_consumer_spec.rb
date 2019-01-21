describe OpenChain::CustomHandler::Vandegrift::StitcherResponseConsumer do

  subject { described_class }

  describe "process_entry_stitch_response" do
    let (:entry) {
      Factory(:entry, entry_number: "1234567890")
    }

    let (:a1) {
      entry.attachments.create! attached_file_name: "test.pdf", attachment_type: Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE, created_at: (Time.zone.now - 1.day)
    }

    let (:stitch_response) {
      {
        'stitch_response' => {
          'reference_info' => {
            'key' => "Entry-#{entry.id}",
            'time' => Time.now.iso8601
          },
          'destination_file' => {'path' => '/bucket/path/to/file.pdf', 'service' => 's3'}
        }
      }
    }

    let (:tempfile) {
      Tempfile.new ['stitch_response', '.pdf']
    }

    after :each do
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
      
      Timecop.freeze(now) do 
        expect(subject.process_stitch_response stitch_response).to eq true
      end

      entry.reload
      expect(entry.attachments.size).to eq(1)
      expect(entry.attachments.first.attachment_type).to eq Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE
      expect(entry.attachments.first.attached_file_name).to eq "#{entry.entry_number}.pdf"
      expect(entry.attachments.first.created_at).to eq Time.iso8601(stitch_response['stitch_response']['reference_info']['time'])
      expect(entry.updated_at).to eq now
    end

    it "does not add new archive if an existing archive is newer" do
      a1.update_column :created_at, (Time.zone.now + 1.day)

      expect(OpenChain::S3).to receive(:download_to_tempfile).with('bucket', 'path/to/file.pdf').and_yield tempfile
      expect(OpenChain::S3).to receive(:delete).with('bucket', 'path/to/file.pdf')
      expect_any_instance_of(Entry).not_to receive(:create_snapshot)

      expect(subject.process_stitch_response stitch_response).to eq true

      entry.reload
      expect(entry.attachments.size).to eq(1)
      expect(entry.attachments.first).to eq a1
    end

    it "raises an error if the stitch request entity isn't found" do
      entry.destroy
      expect{ subject.process_stitch_response stitch_response}.to raise_error ActiveRecord::RecordNotFound
    end

    it "logs an error if the response has an error message" do
      stitch_response['stitch_response']['errors'] = [{'message' => 'This is an error'}]
      expect{ subject.process_stitch_response stitch_response }.to change(ErrorLogEntry,:count).by(1)
    end

    it "swallows specific error response" do
      error = <<-ERR
A pdftk error occurred while stitching together the paths ["file", "file2"]: Error: Unexpected Exception in open_reader()
Unhandled Java Exception:
java.lang.NullPointerException
   at gnu.gcj.runtime.NameFinder.lookup(libgcj.so.14)
   at java.lang.Throwable.getStackTrace(libgcj.so.14)
   at java.lang.Throwable.stackTraceString(libgcj.so.14)
   at java.lang.Throwable.printStackTrace(libgcj.so.14)
   at java.lang.Throwable.printStackTrace(libgcj.so.14)
ERR
      stitch_response['stitch_response']['errors'] = [{'message' => error}]

      expect {
        expect(subject.process_stitch_response stitch_response).to be_nil
      }.to_not change(ErrorLogEntry,:count)
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

end