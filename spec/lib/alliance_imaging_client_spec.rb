require 'spec_helper'

describe OpenChain::AllianceImagingClient do

  describe "bulk_request_images" do
    before :each do
      @e1 = Factory(:entry,:broker_reference=>'123456',:source_system=>'Alliance')
      @e2 = Factory(:entry,:broker_reference=>'654321',:source_system=>'Alliance')
      @e3 = Factory(:entry,:broker_reference=>'777777',:source_system=>'Fenix')
    end
    it 'should request based on primary keys' do
      expect(OpenChain::AllianceImagingClient).to receive(:request_images).with('123456')
      expect(OpenChain::AllianceImagingClient).to receive(:request_images).with('654321')
      OpenChain::AllianceImagingClient.bulk_request_images primary_keys: [@e1.id,@e2.id]
    end
    it 'should request based on search_run_id' do
      expect(OpenChain::AllianceImagingClient).to receive(:request_images).with('123456')
      expect(OpenChain::AllianceImagingClient).to receive(:request_images).with('654321')
      expect(OpenChain::CoreModuleProcessor).to receive(:bulk_objects).with(CoreModule::ENTRY, primary_keys: nil, primary_key_file_bucket: "bucket", primary_key_file_path: "key").and_yield(1, @e1).and_yield(2, @e2)

      OpenChain::AllianceImagingClient.bulk_request_images s3_bucket: "bucket", s3_key: "key"
    end
    it 'should not request for non-alliance entries' do
      expect(OpenChain::AllianceImagingClient).not_to receive(:request_images)
      OpenChain::AllianceImagingClient.bulk_request_images primary_keys: [@e3.id]
    end
  end

  describe "delayed_bulk_request_images" do
    let(:s3_obj) {
      s3_obj = double("OpenChain::S3::UploadResult")
      allow(s3_obj).to receive(:key).and_return "key"
      allow(s3_obj).to receive(:bucket).and_return "bucket"
      s3_obj
    }
    let (:search_run) { SearchRun.create! search_setup_id: Factory(:search_setup).id }

    it "proxies requests with search runs in them" do
      expect(OpenChain::S3).to receive(:create_s3_tempfile).and_return s3_obj
      expect(described_class).to receive(:delay).and_return described_class
      expect(described_class).to receive(:bulk_request_images).with(s3_bucket: "bucket", s3_key: "key")
      described_class.delayed_bulk_request_images search_run.id, nil
    end

    it "forwards primary keys directly" do
      expect(described_class).to receive(:delay).and_return described_class
      expect(described_class).to receive(:bulk_request_images).with(primary_keys: [1, 2, 3])

      described_class.delayed_bulk_request_images nil, [1, 2, 3]
    end
  end

  describe "process_image_file" do
    let (:user) { Factory(:user) }

    before :each do
      @e1 = Factory(:entry,:broker_reference=>'123456',:source_system=>'Alliance')
      # We need to start w/ an actual pdf file as paperclip no longer just uses the file's
      # filename to discover mime type.
      @tempfile = Tempfile.new ["file", ".pdf"]
      @tempfile.binmode
      File.open("#{Rails.root}/spec/fixtures/files/sample.pdf", "rb") do |f|
        @tempfile << f.read
      end
      @hash = {"file_name"=>"file.pdf", "file_number"=>"123456", "doc_desc"=>"Testing",
                "suffix"=>"123456", "doc_date"=>"2016-01-01 00:00"}
    end

    after :each do
      @tempfile.close!
    end

    it 'should be non-private if doc_desc does not start with "private"' do
      entry = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user
      expect(entry).to eq @e1
      expect(entry.attachments[0].is_private).to be_falsey
    end

    it 'should be private if doc_desc starts with "private"' do
      @hash["doc_desc"] = "private_attachment"
      entry = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user
      expect(entry.attachments[0].is_private).to be_truthy
    end

    it 'should load an attachment into the entry with the proper content type' do
      entry = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user

      expect(entry.attachments.size).to eq(1)
      expect(entry.attachments[0].attached_content_type).to eq("application/pdf")
      expect(entry.attachments[0].attachment_type).to eq(@hash["doc_desc"])
      expect(entry.attachments[0].source_system_timestamp).not_to be_nil
      entry.attachments[0].alliance_suffix = @hash["suffix"][2, 3]
      entry.attachments[0].alliance_suffix = @hash["suffix"][0, 2]
    end

    it 'should look for source_system in the message hash and use entry number to lookup for Fenix source system' do
      @hash["source_system"] = 'Fenix'
      @e1.update_attributes :source_system => 'Fenix', :entry_number => "#{@hash['file_number']}", :broker_reference => '654321'

      entry = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user

      expect(entry.attachments.size).to eq(1)
      expect(entry.attachments[0].attached_content_type).to eq("application/pdf")
      expect(entry.attachments[0].attachment_type).to eq(@hash["doc_desc"])
      expect(entry.attachments[0].source_system_timestamp).not_to be_nil
    end

    it 'should generate shell entry records when an entry is missing and the source system is Fenix' do
      # These are the only hash values we should currently expect from the Fenix imaging monitoring process
      @hash = {"source_system" => "Fenix", "file_number" => "123456", "doc_date" => Time.now, "file_name"=>"file.pdf", "doc_desc" => "Source Testing"}
      entry = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user

      expect(entry.entry_number).to eq(@hash["file_number"])
      expect(entry.source_system).to eq('Fenix')
      expect(entry.file_logged_date).to be >= (Time.zone.now - 1.minute)

      expect(entry.attachments.size).to eq(1)
      expect(entry.attachments[0].attached_content_type).to eq("application/pdf")
      expect(entry.attachments[0].attached_file_name).to eq("file.pdf")
      expect(entry.attachments[0].attachment_type).to eq(@hash["doc_desc"])
      expect(entry.attachments[0].source_system_timestamp).not_to be_nil
    end

    it 'should generate shell entry records when an entry is missing and the source system is Alliance' do
      @e1.destroy
      entry = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user

      expect(entry.broker_reference).to eq(@hash["file_number"])
      expect(entry.source_system).to eq('Alliance')
      expect(entry.file_logged_date).to be_nil

      expect(entry.attachments.size).to eq(1)
      expect(entry.attachments[0].attached_content_type).to eq("application/pdf")
      expect(entry.attachments[0].attached_file_name).to eq("file.pdf")
      expect(entry.attachments[0].attachment_type).to eq(@hash["doc_desc"])
      expect(entry.attachments[0].source_system_timestamp).not_to be_nil
    end

    it "skips alliance files that already have revisions higher than the one received" do
      @hash['suffix'] = '00000'

      existing = @e1.attachments.create! alliance_suffix: '000', alliance_revision: 1, attachment_type: @hash['doc_desc']

      enry = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user
      expect(@e1.attachments.size).to eq 1
      expect(@e1.attachments.first).to eq existing
    end

    it "deletes previous versions of the same attachment type / alliance suffix type" do
      existing = @e1.attachments.create! alliance_suffix: '000', alliance_revision: 0, attachment_type: @hash['doc_desc']

      @hash['suffix'] = '01000'
      entry = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user
      expect(@e1.attachments.size).to eq 1
      expect(@e1.attachments.first.alliance_revision).to eq 1
    end

    it "if suffix and revision are the same, it keeps the newest document" do
      @hash['suffix'] = '01000'

      # The existing document is newer, so it should be kept
      existing = @e1.attachments.create! alliance_suffix: '000', alliance_revision: 1, attachment_type: @hash['doc_desc'], source_system_timestamp: Time.zone.parse("2016-03-01 00:00")

      entry = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user
      expect(@e1.attachments.size).to eq 1
      expect(@e1.attachments.first).to eq existing
    end

    it "keeps the image from the request if its newer than an existing document with the same type/revision" do
      @hash['suffix'] = '01000'

      # The existing document is newer, so it should be kept
      existing = @e1.attachments.create! alliance_suffix: '000', alliance_revision: 1, attachment_type: @hash['doc_desc'], source_system_timestamp: Time.zone.parse("2015-03-01 00:00")

      entry = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user
      expect(@e1.attachments.size).to eq 1
      expect(@e1.attachments.first).not_to eq existing
      expect(@e1.attachments.first.attached_file_name).to eq "file.pdf"
    end

    it "snapshots the entry" do
      entry = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user

      expect(entry.entity_snapshots.length).to eq 1
      expect(entry.entity_snapshots.first.context).to eq "Imaging"
    end

    context "Fenix B3 Files" do
      before :each do
        @hash["source_system"] = 'Fenix'
        @e1.update_attributes :source_system => 'Fenix', :entry_number => "#{@hash['file_number']}", :broker_reference => '654321'
        @hash["doc_desc"] = "Automated"
      end

      it "should recognize B3 Automated Fenix files and attach the images as B3 records" do
        @hash['file_name'] = "File_cdc_123128.pdf"
        entry = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user

        expect(entry.attachments.size).to eq(1)
        expect(entry.attachments[0].attached_file_name).to eq(@hash['file_name'])
        expect(entry.attachments[0].attachment_type).to eq("B3")
      end

      it "should retain only 1 B3 attachment" do
        existing = @e1.attachments.build
        existing.attached_file_name = "existing.pdf"
        existing.attachment_type = "B3"
        existing.save

        @hash['file_name'] = "File_cdc_123128.pdf"
        entry = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user

        expect(entry.attachments.size).to eq(1)
        expect(entry.attachments[0].attached_file_name).to eq(@hash['file_name'])
        expect(entry.attachments[0].attachment_type).to eq("B3")
      end

      it "should recognize RNS Automated Fenix files and attach the images as RNS records" do
        @hash['file_name'] = "File_rns_123128.pdf"
        entry = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user

        expect(entry.attachments.size).to eq(1)
        expect(entry.attachments[0].attached_file_name).to eq(@hash['file_name'])
        expect(entry.attachments[0].attachment_type).to eq("Customs Release Notice")
      end

      it "should retain only 1 RNS attachment" do
        existing = @e1.attachments.build
        existing.attached_file_name = "existing.pdf"
        existing.attachment_type = "Customs Release Notice"
        existing.save

        @hash['file_name'] = "File_rns_123128.pdf"
        entry = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user

        expect(entry.attachments.size).to eq(1)
        expect(entry.attachments[0].attached_file_name).to eq(@hash['file_name'])
        expect(entry.attachments[0].attachment_type).to eq("Customs Release Notice")
      end

      it "should recognize B3 Recap Automated Fenix files and attach the images as recap records" do
        @hash['file_name'] = "File_recap_123128.pdf"
        entry = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user

        expect(entry.attachments.size).to eq(1)
        expect(entry.attachments[0].attached_file_name).to eq(@hash['file_name'])
        expect(entry.attachments[0].attachment_type).to eq("B3 Recap")
      end

      it "should retain only 1 recap attachment" do
        existing = @e1.attachments.build
        existing.attached_file_name = "existing.pdf"
        existing.attachment_type = "B3 Recap"
        existing.save

        @hash['file_name'] = "File_recap_123128.pdf"
        entry = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user

        expect(entry.attachments.size).to eq(1)
        expect(entry.attachments[0].attached_file_name).to eq(@hash['file_name'])
        expect(entry.attachments[0].attachment_type).to eq("B3 Recap")
      end
    end
  end

  describe "consume_images" do

    let (:user) {
      u = instance_double(User)
      allow(User).to receive(:integration).and_return u
      u
    }

    let (:config) {
      {"sqs_receive_queue" => "sqs"}.with_indifferent_access
    }

    let (:hash) { {"file_name" => "file.txt", "s3_bucket" => "bucket", "s3_key" => "key"} }

    before :each do 
      allow(OpenChain::AllianceImagingClient).to receive(:imaging_config).and_return config
    end

    it "should use SQS queue to download messages and use the S3 client with tempfile to download the file" do
      # This is mostly just mocks, but I wanted to ensure the expected calls are actually happening
      t = double
      expect(OpenChain::SQS).to receive(:poll).with("sqs", visibility_timeout: 300).and_yield hash
      expect(OpenChain::S3).to receive(:download_to_tempfile).with(hash["s3_bucket"], hash["s3_key"], {}).and_return(t)
      expect(OpenChain::AllianceImagingClient).to receive(:process_image_file).with(t, hash, user)

      OpenChain::AllianceImagingClient.consume_images
    end

    it "passes s3 version if present" do
      # This is mostly just mocks, but I wanted to ensure the expected calls are actually happening
      hash["s3_version"] = "version"
      t = double
      expect(OpenChain::SQS).to receive(:poll).with("sqs", visibility_timeout: 300).and_yield hash
      expect(OpenChain::S3).to receive(:download_to_tempfile).with(hash["s3_bucket"], hash["s3_key"], {version: "version"}).and_return(t)
      expect(OpenChain::AllianceImagingClient).to receive(:process_image_file).with(t, hash, user)

      OpenChain::AllianceImagingClient.consume_images
    end

    it "handles errors and retries polling" do
      error = StandardError.new
      expect(OpenChain::SQS).to receive(:poll).exactly(10).times.and_raise error
      expect(error).to receive(:log_me).with(["Alliance imaging client hash: "]).exactly(10).times

      OpenChain::AllianceImagingClient.consume_images
    end
  end

  describe "send_entry_stitch_request" do
    before :each do
      @entry = Factory(:entry, importer: Factory(:company))
      @a1 = @entry.attachments.create! attached_file_name: "test.pdf", attachment_type: "A"
      @a2 = @entry.attachments.create! attached_file_name: "test2.pdf", attachment_type: "B"
      @archive_setup = AttachmentArchiveSetup.create! company_id: @entry.importer_id, combine_attachments: true, combined_attachment_order: "B\nA"
    end

    it "does nothing if the archive setup isn't turned on for combining attachments" do
      @archive_setup.update_attributes! combine_attachments: false
      expect(OpenChain::AllianceImagingClient.send_entry_stitch_request @entry.id).to be_falsey
    end

    it "does nothing if the importer doesn't have an archive setup" do
      @archive_setup.destroy
      expect(OpenChain::AllianceImagingClient.send_entry_stitch_request @entry.id).to be_falsey
    end

    it "sends a stitch request for an entry, ordering files based on archive setup order" do
      queue_name = nil
      stitch_request = nil
      expect(OpenChain::SQS).to receive(:send_json) do |queue, request|
        queue_name = queue
        stitch_request = request
      end
      expect_any_instance_of(Time).to receive(:iso8601).and_return "time"
      expect(OpenChain::AllianceImagingClient.send_entry_stitch_request @entry.id).to be_truthy
      # See the config/stitcher.yml file for queue name
      expect(queue_name).to eq "test-request-queue"
      expect(stitch_request).to eq ({
        'stitch_request' => {
          'source_files' => [
            {'path' => "/chain-io/#{MasterSetup.get.uuid}/attachment/#{@a2.id}/#{@a2.attached_file_name}", 'service' => "s3"},
            {'path' => "/chain-io/#{MasterSetup.get.uuid}/attachment/#{@a1.id}/#{@a1.attached_file_name}", 'service' => "s3"}
          ],
          'reference_info' => {
            'key'=>"Entry-#{@entry.id}",
            'time'=>"time"
          },
          'destination_file' => {'path' => "/chain-io/#{MasterSetup.get.uuid}/stitched/Entry-#{@entry.id}.pdf", 'service' => "s3"}
        }
      })
      expect(StitchQueueItem.where(stitch_type: Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE, stitch_queuable_type: 'Entry', stitch_queuable_id: @entry.id).first).to_not be_nil
    end

    it 'orders multiple of the same attachment types by updated_at ASC' do
      @a2.update_attributes! attachment_type: @a1.attachment_type
      @a2.update_column :updated_at, 1.year.ago

      stitch_request = nil
      expect(OpenChain::SQS).to receive(:send_json) do |queue, request|
        stitch_request = request
      end

      expect(OpenChain::AllianceImagingClient.send_entry_stitch_request @entry.id).to be_truthy

      expect(stitch_request['stitch_request']['source_files']).to eq [
        {'path' => "/chain-io/#{MasterSetup.get.uuid}/attachment/#{@a2.id}/#{@a2.attached_file_name}", 'service' => "s3"},
        {'path' => "/chain-io/#{MasterSetup.get.uuid}/attachment/#{@a1.id}/#{@a1.attached_file_name}", 'service' => "s3"}
      ]
    end

    it 'orders attachment types not in combined_attachment_order by updated date' do
      @a2.update_attributes! attachment_type: ""
      @a2.update_column :updated_at, 1.year.ago
      a3 = @entry.attachments.create! attached_file_name: "test3.pdf", attachment_type: ""


      stitch_request = nil
      expect(OpenChain::SQS).to receive(:send_json) do |queue, request|
        stitch_request = request
      end

      expect(OpenChain::AllianceImagingClient.send_entry_stitch_request @entry.id).to be_truthy

      expect(stitch_request['stitch_request']['source_files']).to eq [
        {'path' => "/chain-io/#{MasterSetup.get.uuid}/attachment/#{@a1.id}/#{@a1.attached_file_name}", 'service' => "s3"},
        {'path' => "/chain-io/#{MasterSetup.get.uuid}/attachment/#{@a2.id}/#{@a2.attached_file_name}", 'service' => "s3"},
        {'path' => "/chain-io/#{MasterSetup.get.uuid}/attachment/#{a3.id}/#{a3.attached_file_name}", 'service' => "s3"}
      ]
    end

    it 'skips non image formats' do
      @a2.update_attributes! attached_file_name: "file.zip"

      stitch_request = nil
      expect(OpenChain::SQS).to receive(:send_json) do |queue, request|
        stitch_request = request
      end

      expect(OpenChain::AllianceImagingClient.send_entry_stitch_request @entry.id).to be_truthy

      expect(stitch_request['stitch_request']['source_files']).to eq [
        {'path' => "/chain-io/#{MasterSetup.get.uuid}/attachment/#{@a1.id}/#{@a1.attached_file_name}", 'service' => "s3"}
      ]
    end

    it 'skips sending when no attachments need to be sent' do
      @entry.attachments.update_all attached_file_name: "file.zip"

      expect(OpenChain::AllianceImagingClient.send_entry_stitch_request @entry.id).to be_falsey
    end

    it "doesn't fail if the entry doesn't exist" do
      expect(OpenChain::AllianceImagingClient.send_entry_stitch_request -1).to be_falsey
    end

    it "handles entries missing importers" do
      @entry.update_attributes! importer: nil
      expect(OpenChain::AllianceImagingClient.send_entry_stitch_request @entry.id).to be_falsey
    end
  end

  describe "process_entry_stitch_response" do
    before :each do
      stub_paperclip
      @entry = Factory(:entry, entry_number: "1234567890")
      @a1 = @entry.attachments.create! attached_file_name: "test.pdf", attachment_type: Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE
      @resp = {
        'stitch_response' => {
          'reference_info' => {
            'key' => "Entry-#{@entry.id}",
            'time' => Time.now.iso8601
          },
          'destination_file' => {'path' => '/bucket/path/to/file.pdf', 'service' => 's3'}
        }
      }
      @t = Tempfile.new ['stitch_response', '.pdf']
    end

    after :each do
      @t.close!
    end

    it "reads a stitch response and updates an entry's attachments with an archive packet" do
      StitchQueueItem.create! stitch_type: Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE, stitch_queuable_type: 'Entry', stitch_queuable_id: @entry.id
      expect(OpenChain::S3).to receive(:download_to_tempfile).with('bucket', 'path/to/file.pdf').and_yield @t
      expect(OpenChain::S3).to receive(:delete).with('bucket', 'path/to/file.pdf')

      expect(OpenChain::AllianceImagingClient.process_entry_stitch_response @resp).to be_truthy

      @entry.reload
      expect(@entry.attachments.size).to eq(1)
      expect(@entry.attachments.first.attachment_type).to eq Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE
      expect(@entry.attachments.first.attached_file_name).to eq "#{@entry.entry_number}.pdf"
      expect(@entry.attachments.first.created_at).to eq Time.iso8601(@resp['stitch_response']['reference_info']['time'])
      expect(StitchQueueItem.where(stitch_queuable_type: 'Entry', stitch_queuable_id: @entry.id).first).to be_nil
    end

    it "raises an error if the stitch request entity isn't found" do
      @entry.destroy
      expect{OpenChain::AllianceImagingClient.process_entry_stitch_response @resp}.to raise_error ActiveRecord::RecordNotFound
    end

    it "logs an error if the response has an error message" do
      @resp['stitch_response']['errors'] = [{'message' => 'This is an error'}]


      expect{OpenChain::AllianceImagingClient.process_entry_stitch_response @resp}.to change(ErrorLogEntry,:count).by(1)
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
      @resp['stitch_response']['errors'] = [{'message' => error}]

      expect {
        expect(OpenChain::AllianceImagingClient.process_entry_stitch_response @resp).to be_nil
      }.to_not change(ErrorLogEntry,:count)
    end
  end

  describe "send_outstanding_stitch_requests" do
    before :each do
      @entry = Factory(:entry, importer: Factory(:company))
      @broker_invoice = Factory(:broker_invoice, entry: @entry, invoice_date: '2014-01-01')
      @attachment = @entry.attachments.create! attached_file_name: "test.pdf", attachment_type: "A"
      @archive_packet = @entry.attachments.create! attached_file_name: "test2.pdf", attachment_type: Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE, created_at: (@attachment.updated_at - 1.day)
      @archive_setup = AttachmentArchiveSetup.create! company_id: @entry.importer_id, combine_attachments: true, start_date: '2014-01-01'
    end

    it "sends stitch requests when an attachment is updated after the archive packet" do
      expect(OpenChain::AllianceImagingClient).to receive(:send_entry_stitch_request).with @entry.id
      expect(OpenChain::AllianceImagingClient.send_outstanding_stitch_requests).to be_nil
    end

    it "sends stitch requests when no archive packets are present" do
      @archive_packet.destroy
      expect(OpenChain::AllianceImagingClient).to receive(:send_entry_stitch_request).with @entry.id
      expect(OpenChain::AllianceImagingClient.send_outstanding_stitch_requests).to be_nil
    end

    it "does not send stitch requests for importers not using the stitching process" do
      @archive_setup.update_attributes! combine_attachments: false
      expect(OpenChain::AllianceImagingClient).not_to receive(:send_entry_stitch_request).with @entry.id
      expect(OpenChain::AllianceImagingClient.send_outstanding_stitch_requests).to be_nil
    end

    it "does not send stitch requests when the archive packet is up to date" do
      @attachment.update_attributes! updated_at: @archive_packet.created_at - 1.day
      expect(OpenChain::AllianceImagingClient).not_to receive(:send_entry_stitch_request).with @entry.id
      expect(OpenChain::AllianceImagingClient.send_outstanding_stitch_requests).to be_nil
    end

    it "does not send stitch requests when a non-stitchable attachment is updated" do
      @attachment.update_attributes! attached_file_name: "file.notstitchable"
      expect(OpenChain::AllianceImagingClient).not_to receive(:send_entry_stitch_request).with @entry.id
      expect(OpenChain::AllianceImagingClient.send_outstanding_stitch_requests).to be_nil
    end

    it 'does not send stitch requests for entries that will not have attachments archived' do
      @broker_invoice.update_attributes! invoice_date: '2013-12-31'
      expect(OpenChain::AllianceImagingClient).not_to receive(:send_entry_stitch_request).with @entry.id
      expect(OpenChain::AllianceImagingClient.send_outstanding_stitch_requests).to be_nil
    end

    it 'does not send stitch requests for entries that do not have invoices' do
      @broker_invoice.destroy
      expect(OpenChain::AllianceImagingClient).not_to receive(:send_entry_stitch_request).with @entry.id
      expect(OpenChain::AllianceImagingClient.send_outstanding_stitch_requests).to be_nil
    end
    it 'does not send a stitch request if there is already one queued' do
      StitchQueueItem.create! stitch_type: Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE, stitch_queuable_type: 'Entry', stitch_queuable_id: @entry.id
      expect(OpenChain::AllianceImagingClient).not_to receive(:send_entry_stitch_request).with @entry.id
      expect(OpenChain::AllianceImagingClient.send_outstanding_stitch_requests).to be_nil
    end

    it "does not send stitch request if only attachment is private" do
      @attachment.update_attributes! is_private: true
      expect(OpenChain::AllianceImagingClient).not_to receive(:send_entry_stitch_request).with @entry.id
      expect(OpenChain::AllianceImagingClient.send_outstanding_stitch_requests).to be_nil
    end
  end

  describe "run_schedulable" do
    it "implements SchedulableJob interface" do
      allow(OpenChain::AllianceImagingClient).to receive(:delay).and_return OpenChain::AllianceImagingClient
      expect(OpenChain::AllianceImagingClient).to receive(:consume_images)
      expect(OpenChain::AllianceImagingClient).to receive(:consume_stitch_responses)
      expect(OpenChain::AllianceImagingClient).to receive(:send_outstanding_stitch_requests)

      OpenChain::AllianceImagingClient.run_schedulable
    end

    it "does not call consume_images if 2 jobs are already running" do
      expect(OpenChain::AllianceImagingClient).to receive(:queued_jobs_for_method).with(OpenChain::AllianceImagingClient, :consume_images).and_return 2

      allow(OpenChain::AllianceImagingClient).to receive(:delay).and_return OpenChain::AllianceImagingClient
      expect(OpenChain::AllianceImagingClient).not_to receive(:consume_images)
      expect(OpenChain::AllianceImagingClient).to receive(:consume_stitch_responses)
      expect(OpenChain::AllianceImagingClient).to receive(:send_outstanding_stitch_requests)

      OpenChain::AllianceImagingClient.run_schedulable
    end
  end

  describe "process_fenix_nd_image_file" do
    before :each do
      @message = {"source_system" => "Fenix", "export_process" => "sql_proxy", "doc_date" => "2015-09-04T05:30:35-10:00", "s3_key"=>"path/to/file.txt", "s3_bucket" => "bucket",
                  "file_number" => "11981001795105 ", "doc_desc" => "B3", "file_name" => "_11981001795105 _B3_01092015 14.24.42 PM.pdf", "version" => nil, "public" => true}
      # We need to start w/ an actual pdf file as paperclip no longer just uses the file's
      # filename to discover mime type.
      @tempfile = Tempfile.new ["file", ".pdf"]
      @tempfile.binmode
      File.open("#{Rails.root}/spec/fixtures/files/sample.pdf", "rb") do |f|
        @tempfile << f.read
      end
    end

    let (:user) { Factory(:user) }

    after :each do
      @tempfile.close! if @tempfile
    end

    it "saves attachment data to entry" do
      expect(Lock).to receive(:acquire).with(Lock::FENIX_PARSER_LOCK, times: 3).and_yield
      expect(Lock).to receive(:with_lock_retry).with(instance_of(Entry)).and_yield
      entry = OpenChain::AllianceImagingClient.process_fenix_nd_image_file @tempfile, @message, user

      expect(entry).not_to be_nil
      expect(entry.entry_number).to eq "11981001795105"
      expect(entry.source_system).to eq "Fenix"
      expect(entry.file_logged_date).to be_within(1.minute).of Time.zone.now

      a = entry.attachments.first
      expect(a).not_to be_nil
      expect(a.attachment_type).to eq "B3"
      expect(a.source_system_timestamp).to eq Time.zone.parse("2015-09-04T05:30:35-10:00")
      expect(a.is_private).to be_nil
      expect(a.attached_file_name).to eq "11981001795105 _B3_01092015 14.24.42 PM.pdf"

      expect(entry.entity_snapshots.length).to eq 1
      expect(entry.entity_snapshots.first.context).to eq "Imaging"
    end

    it "adds attachment to an existing entry" do
      e = Factory(:entry, entry_number: "11981001795105", source_system: "Fenix")

      OpenChain::AllianceImagingClient.process_fenix_nd_image_file @tempfile, @message, user
      e.reload
      expect(e.attachments.size).to eq 1
    end

    it "adds attachment to an existing entry even if the name and type are the same" do
      @message["doc_desc"] = "Type"
      e = Factory(:entry, entry_number: "11981001795105", source_system: "Fenix")
      e.attachments.create! attachment_type: "Type", attached_file_name: "11981001795105 _B3_01092015 14.24.42 PM.pdf", source_system_timestamp: "2015-09-04T04:30:35-10:00"

      e = OpenChain::AllianceImagingClient.process_fenix_nd_image_file @tempfile, @message, user
      expect(e.attachments.size).to eq 2
      expect(e.attachments.map {|a| a.attached_file_name }.uniq).to eq ["11981001795105 _B3_01092015 14.24.42 PM.pdf"]
    end

    it "replaces previous versions of B3 attachment" do
      e = Factory(:entry, entry_number: "11981001795105", source_system: "Fenix")
      e.attachments.create! attachment_type: "B3", source_system_timestamp: "2015-09-04T04:30:35-10:00"
      e.attachments.create! attachment_type: "B3", source_system_timestamp: "2015-09-04T03:30:35-10:00"

      e = OpenChain::AllianceImagingClient.process_fenix_nd_image_file @tempfile, @message, user
      expect(e.attachments.size).to eq 1
      expect(e.attachments.first.attached_file_name).to eq "11981001795105 _B3_01092015 14.24.42 PM.pdf"
    end

    it "does not save files that have newer versions attached to the entry" do
      e = Factory(:entry, entry_number: "11981001795105", source_system: "Fenix")
      e.attachments.create! attachment_type: "B3", source_system_timestamp: "2015-09-05T04:30:35-10:00", attached_file_name: "file.pdf"

      e = OpenChain::AllianceImagingClient.process_fenix_nd_image_file @tempfile, @message, user
      e.reload
      expect(e.attachments.size).to eq 1
      expect(e.attachments.first.attached_file_name).to eq "file.pdf"
    end

    it "replaces previous versions of RNS attachment" do
      @message['doc_desc'] = "RNS"
      e = Factory(:entry, entry_number: "11981001795105", source_system: "Fenix")
      e.attachments.create! attachment_type: "RNS", source_system_timestamp: "2015-09-04T04:30:35-10:00"

      e = OpenChain::AllianceImagingClient.process_fenix_nd_image_file @tempfile, @message, user
      expect(e.attachments.size).to eq 1
      expect(e.attachments.first.attached_file_name).to eq "11981001795105 _B3_01092015 14.24.42 PM.pdf"
    end

    it "replaces previous versions of B3 Recap attachment" do
      @message['doc_desc'] = "B3 Recap"
      e = Factory(:entry, entry_number: "11981001795105", source_system: "Fenix")
      e.attachments.create! attachment_type: "B3 Recap", source_system_timestamp: "2015-09-04T04:30:35-10:00"

      e = OpenChain::AllianceImagingClient.process_fenix_nd_image_file @tempfile, @message, user
      expect(e.attachments.size).to eq 1
      expect(e.attachments.first.attached_file_name).to eq "11981001795105 _B3_01092015 14.24.42 PM.pdf"
    end

    it 'replaces previous versions of billing invoices' do
      @message['doc_desc'] = "Invoice"
      @message['file_name'] = "invoice 123.pdf"
      e = Factory(:entry, entry_number: "11981001795105", source_system: "Fenix")
      a1 = e.attachments.create! attachment_type: "Invoice", source_system_timestamp: "2015-09-04T04:30:35-10:00", attached_file_name: "invoice 123.pdf"
      e.attachments.create! attachment_type: "Invoice", source_system_timestamp: "2015-09-04T04:30:35-10:00", attached_file_name: "invoice 345.pdf"

      e = OpenChain::AllianceImagingClient.process_fenix_nd_image_file @tempfile, @message, user
      expect(e.attachments.size).to eq 2
      expect(e.attachments.map {|a| a.attached_file_name}.sort).to eq ["invoice 123.pdf", "invoice 345.pdf"]
      #make sure the new file referenced by message was the one that got created, and the existing one got removed
      expect(e.attachments).not_to include a1
    end

    it "replaces previous versions of B3 Recap attachment" do
      @message['doc_desc'] = "Cartage Slip"
      e = Factory(:entry, entry_number: "11981001795105", source_system: "Fenix")
      e.attachments.create! attachment_type: "Cartage Slip", source_system_timestamp: "2015-09-04T04:30:35-10:00"

      OpenChain::AllianceImagingClient.process_fenix_nd_image_file @tempfile, @message, user

      e.reload
      expect(e.attachments.size).to eq 1
      expect(e.attachments.first.attached_file_name).to eq "11981001795105 _B3_01092015 14.24.42 PM.pdf"
    end

  end
end
