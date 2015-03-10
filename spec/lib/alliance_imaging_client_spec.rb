require 'spec_helper'

describe OpenChain::AllianceImagingClient do
  describe :bulk_request_images do
    before :each do
      @e1 = Factory(:entry,:broker_reference=>'123456',:source_system=>'Alliance')
      @e2 = Factory(:entry,:broker_reference=>'654321',:source_system=>'Alliance')
      @e3 = Factory(:entry,:broker_reference=>'777777',:source_system=>'Fenix')
    end
    it 'should request based on primary keys' do
      OpenChain::AllianceImagingClient.should_receive(:request_images).with('123456')
      OpenChain::AllianceImagingClient.should_receive(:request_images).with('654321')
      OpenChain::AllianceImagingClient.bulk_request_images nil, [@e1.id,@e2.id]
    end
    it 'should request based on search_run_id' do
      OpenChain::AllianceImagingClient.should_receive(:request_images).with('123456')
      OpenChain::AllianceImagingClient.should_receive(:request_images).with('654321')
      ss = Factory(:search_setup,:module_type=>"Entry",:user=>Factory(:master_user))
      ss.search_runs.create!
      OpenChain::AllianceImagingClient.bulk_request_images ss.search_runs.first.id, nil
    end
    it 'should not request for non-alliance entries' do
      OpenChain::AllianceImagingClient.should_not_receive(:request_images)
      OpenChain::AllianceImagingClient.bulk_request_images nil, [@e3.id]
    end
  end

  describe :process_image_file do
    before :each do
      stub_paperclip
      @e1 = Factory(:entry,:broker_reference=>'123456',:source_system=>'Alliance')
      # We need to start w/ an actual pdf file as paperclip no longer just uses the file's
      # filename to discover mime type.
      @tempfile = Tempfile.new ["file", ".pdf"]
      @tempfile.binmode
      File.open("#{Rails.root}/spec/fixtures/files/sample.pdf", "rb") do |f|
        @tempfile << f.read
      end
      @hash = {"file_name"=>"file.pdf", "file_number"=>"123456", "doc_desc"=>"Testing", 
                "suffix"=>"123456", "doc_date"=>Time.now}
    end

    after :each do
      @tempfile.close!
    end

    it 'should be non-private if doc_desc does not start with "private"' do
      OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash
      entry = Entry.find(@e1.id)
      entry.attachments[0].is_private.should be_false
    end

    it 'should be private if doc_desc starts with "private"' do
      @hash["doc_desc"] = "private_attachment"
      OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash
      entry = Entry.find(@e1.id)
      entry.attachments[0].is_private.should be_true
    end

    it 'should load an attachment into the entry with the proper content type' do
      OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash

      entry = Entry.find(@e1.id)
      entry.attachments.size.should == 1
      entry.attachments[0].attached_content_type.should == "application/pdf"
      entry.attachments[0].attachment_type.should == @hash["doc_desc"]
      entry.attachments[0].source_system_timestamp.should_not be_nil
      entry.attachments[0].alliance_suffix = @hash["suffix"][2, 3]
      entry.attachments[0].alliance_suffix = @hash["suffix"][0, 2]
    end

    it 'should look for source_system in the message hash and use entry number to lookup for Fenix source system' do
      @hash["source_system"] = 'Fenix'
      @e1.update_attributes :source_system => 'Fenix', :entry_number => "#{@hash['file_number']}", :broker_reference => '654321'

      OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash

      entry = Entry.find(@e1.id)
      entry.attachments.size.should == 1
      entry.attachments[0].attached_content_type.should == "application/pdf"
      entry.attachments[0].attachment_type.should == @hash["doc_desc"]
      entry.attachments[0].source_system_timestamp.should_not be_nil
    end

    it 'should generate shell entry records when an entry is missing and the source system is Fenix' do
      # These are the only hash values we should currently expect from the Fenix imaging monitoring process
      @hash = {"source_system" => "Fenix", "file_number" => "123456", "doc_date" => Time.now, "file_name"=>"file.pdf", "doc_desc" => "Source Testing"}
      OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash
      
      entry = Entry.find_by_entry_number_and_source_system @hash["file_number"], 'Fenix'
      entry.should_not be_nil
      entry.entry_number.should == @hash["file_number"]
      entry.source_system.should == 'Fenix'
      entry.file_logged_date.should >= (Time.zone.now - 1.minute)

      entry.attachments.size.should == 1
      entry.attachments[0].attached_content_type.should == "application/pdf"
      entry.attachments[0].attached_file_name.should == "file.pdf"
      entry.attachments[0].attachment_type.should == @hash["doc_desc"]
      entry.attachments[0].source_system_timestamp.should_not be_nil
    end

    it "skips alliance files that already have revisions higher than the one received" do
      @hash['suffix'] = '00000'

      existing = @e1.attachments.create! alliance_suffix: '000', alliance_revision: 1, attachment_type: @hash['doc_desc']

      OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash

      @e1.reload
      expect(@e1.attachments.size).to eq 1
      expect(@e1.attachments.first).to eq existing
    end

    it "deletes previous versions of the same attachment type / alliance suffix type" do
      existing = @e1.attachments.create! alliance_suffix: '000', alliance_revision: 0, attachment_type: @hash['doc_desc']

      @hash['suffix'] = '01000'
      OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash

      @e1.reload
      expect(@e1.attachments.size).to eq 1
      expect(@e1.attachments.first.alliance_revision).to eq 1
    end

    context "Fenix B3 Files" do
      before :each do 
        @hash["source_system"] = 'Fenix'
        @e1.update_attributes :source_system => 'Fenix', :entry_number => "#{@hash['file_number']}", :broker_reference => '654321'
        @hash["doc_desc"] = "Automated"
      end

      it "should recognize B3 Automated Fenix files and attach the images as B3 records" do
        @hash['file_name'] = "File_cdc_123128.pdf"
        OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash

        entry = Entry.find_by_entry_number_and_source_system @hash["file_number"], 'Fenix'
        entry.attachments.size.should == 1
        entry.attachments[0].attached_file_name.should == @hash['file_name']
        entry.attachments[0].attachment_type.should == "B3"
      end

      it "should retain only 1 B3 attachment" do
        existing = @e1.attachments.build
        existing.attached_file_name = "existing.pdf"
        existing.attachment_type = "B3"
        existing.save

        @hash['file_name'] = "File_cdc_123128.pdf"
        OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash

        entry = Entry.find_by_entry_number_and_source_system @hash["file_number"], 'Fenix'
        entry.attachments.size.should == 1
        entry.attachments[0].attached_file_name.should == @hash['file_name']
        entry.attachments[0].attachment_type.should == "B3"
      end

      it "should recognize RNS Automated Fenix files and attach the images as RNS records" do
        @hash['file_name'] = "File_rns_123128.pdf"
        OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash

        entry = Entry.find_by_entry_number_and_source_system @hash["file_number"], 'Fenix'
        entry.attachments.size.should == 1
        entry.attachments[0].attached_file_name.should == @hash['file_name']
        entry.attachments[0].attachment_type.should == "Customs Release Notice"
      end

      it "should retain only 1 RNS attachment" do
        existing = @e1.attachments.build
        existing.attached_file_name = "existing.pdf"
        existing.attachment_type = "Customs Release Notice"
        existing.save

        @hash['file_name'] = "File_rns_123128.pdf"
        OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash

        entry = Entry.find_by_entry_number_and_source_system @hash["file_number"], 'Fenix'
        entry.attachments.size.should == 1
        entry.attachments[0].attached_file_name.should == @hash['file_name']
        entry.attachments[0].attachment_type.should == "Customs Release Notice"
      end

      it "should recognize B3 Recap Automated Fenix files and attach the images as recap records" do
        @hash['file_name'] = "File_recap_123128.pdf"
        OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash

        entry = Entry.find_by_entry_number_and_source_system @hash["file_number"], 'Fenix'
        entry.attachments.size.should == 1
        entry.attachments[0].attached_file_name.should == @hash['file_name']
        entry.attachments[0].attachment_type.should == "B3 Recap"
      end

      it "should retain only 1 recap attachment" do
        existing = @e1.attachments.build
        existing.attached_file_name = "existing.pdf"
        existing.attachment_type = "B3 Recap"
        existing.save

        @hash['file_name'] = "File_recap_123128.pdf"
        OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash

        entry = Entry.find_by_entry_number_and_source_system @hash["file_number"], 'Fenix'
        entry.attachments.size.should == 1
        entry.attachments[0].attached_file_name.should == @hash['file_name']
        entry.attachments[0].attachment_type.should == "B3 Recap"
      end
    end
  end

  describe :consume_images do
    it "should use SQS queue to download messages and use the S3 client with tempfile to download the file" do
      # This is mostly just mocks, but I wanted to ensure the expected calls are actualy happening
      hash = {"file_name" => "file.txt", "s3_bucket" => "bucket", "s3_key" => "key"}
      t = double
      OpenChain::SQS.should_receive(:retrieve_messages_as_hash).with("https://queue.amazonaws.com/468302385899/alliance-img-doc-test").and_yield hash
      OpenChain::S3.should_receive(:download_to_tempfile).with(hash["s3_bucket"], hash["s3_key"]).and_return(t)
      OpenChain::AllianceImagingClient.should_receive(:process_image_file).with(t, hash)

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
      expect(OpenChain::AllianceImagingClient.send_entry_stitch_request @entry.id).to be_false
    end

    it "does nothing if the importer doesn't have an archive setup" do
      @archive_setup.destroy
      expect(OpenChain::AllianceImagingClient.send_entry_stitch_request @entry.id).to be_false
    end

    it "sends a stitch request for an entry, ordering files based on archive setup order" do
      queue_name = nil
      stitch_request = nil
      OpenChain::SQS.should_receive(:send_json) do |queue, request|
        queue_name = queue
        stitch_request = request
      end
      Time.any_instance.should_receive(:iso8601).and_return "time"
      expect(OpenChain::AllianceImagingClient.send_entry_stitch_request @entry.id).to be_true
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
      OpenChain::SQS.should_receive(:send_json) do |queue, request|
        stitch_request = request
      end

      expect(OpenChain::AllianceImagingClient.send_entry_stitch_request @entry.id).to be_true

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
      OpenChain::SQS.should_receive(:send_json) do |queue, request|
        stitch_request = request
      end

      expect(OpenChain::AllianceImagingClient.send_entry_stitch_request @entry.id).to be_true

      expect(stitch_request['stitch_request']['source_files']).to eq [
        {'path' => "/chain-io/#{MasterSetup.get.uuid}/attachment/#{@a1.id}/#{@a1.attached_file_name}", 'service' => "s3"},
        {'path' => "/chain-io/#{MasterSetup.get.uuid}/attachment/#{@a2.id}/#{@a2.attached_file_name}", 'service' => "s3"},
        {'path' => "/chain-io/#{MasterSetup.get.uuid}/attachment/#{a3.id}/#{a3.attached_file_name}", 'service' => "s3"}
      ]
    end

    it 'skips non image formats' do
      @a2.update_attributes! attached_file_name: "file.zip"

      stitch_request = nil
      OpenChain::SQS.should_receive(:send_json) do |queue, request|
        stitch_request = request
      end

      expect(OpenChain::AllianceImagingClient.send_entry_stitch_request @entry.id).to be_true

      expect(stitch_request['stitch_request']['source_files']).to eq [
        {'path' => "/chain-io/#{MasterSetup.get.uuid}/attachment/#{@a1.id}/#{@a1.attached_file_name}", 'service' => "s3"}
      ]
    end

    it 'skips sending when no attachments need to be sent' do
      @entry.attachments.update_all attached_file_name: "file.zip"

      expect(OpenChain::AllianceImagingClient.send_entry_stitch_request @entry.id).to be_false
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
      OpenChain::S3.should_receive(:download_to_tempfile).with('bucket', 'path/to/file.pdf').and_yield @t
      OpenChain::S3.should_receive(:delete).with('bucket', 'path/to/file.pdf')
      
      expect(OpenChain::AllianceImagingClient.process_entry_stitch_response @resp).to be_true

      @entry.reload
      expect(@entry.attachments).to have(1).item
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
      StandardError.any_instance.should_receive(:log_me)

      expect(OpenChain::AllianceImagingClient.process_entry_stitch_response @resp).to be_nil
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

      StandardError.any_instance.should_not_receive(:log_me)

      expect(OpenChain::AllianceImagingClient.process_entry_stitch_response @resp).to be_nil
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
      OpenChain::AllianceImagingClient.should_receive(:send_entry_stitch_request).with @entry.id
      expect(OpenChain::AllianceImagingClient.send_outstanding_stitch_requests).to be_nil
    end

    it "sends stitch requests when no archive packets are present" do
      @archive_packet.destroy
      OpenChain::AllianceImagingClient.should_receive(:send_entry_stitch_request).with @entry.id
      expect(OpenChain::AllianceImagingClient.send_outstanding_stitch_requests).to be_nil
    end

    it "does not send stitch requests for importers not using the stitching process" do
      @archive_setup.update_attributes! combine_attachments: false
      OpenChain::AllianceImagingClient.should_not_receive(:send_entry_stitch_request).with @entry.id
      expect(OpenChain::AllianceImagingClient.send_outstanding_stitch_requests).to be_nil
    end

    it "does not send stitch requests when the archive packet is up to date" do
      @attachment.update_attributes! updated_at: @archive_packet.created_at - 1.day
      OpenChain::AllianceImagingClient.should_not_receive(:send_entry_stitch_request).with @entry.id
      expect(OpenChain::AllianceImagingClient.send_outstanding_stitch_requests).to be_nil
    end

    it "does not send stitch requests when a non-stitchable attachment is updated" do
      @attachment.update_attributes! attached_file_name: "file.notstitchable"
      OpenChain::AllianceImagingClient.should_not_receive(:send_entry_stitch_request).with @entry.id
      expect(OpenChain::AllianceImagingClient.send_outstanding_stitch_requests).to be_nil
    end

    it 'does not send stitch requests for entries that will not have attachments archived' do
      @broker_invoice.update_attributes! invoice_date: '2013-12-31'
      OpenChain::AllianceImagingClient.should_not_receive(:send_entry_stitch_request).with @entry.id
      expect(OpenChain::AllianceImagingClient.send_outstanding_stitch_requests).to be_nil
    end

    it 'does not send stitch requests for entries that do not have invoices' do
      @broker_invoice.destroy
      OpenChain::AllianceImagingClient.should_not_receive(:send_entry_stitch_request).with @entry.id
      expect(OpenChain::AllianceImagingClient.send_outstanding_stitch_requests).to be_nil
    end
    it 'does not send a stitch request if there is already one queued' do
      StitchQueueItem.create! stitch_type: Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE, stitch_queuable_type: 'Entry', stitch_queuable_id: @entry.id
      OpenChain::AllianceImagingClient.should_not_receive(:send_entry_stitch_request).with @entry.id
      expect(OpenChain::AllianceImagingClient.send_outstanding_stitch_requests).to be_nil
    end
  end

  describe "run_schedulable" do
    it "implements SchedulableJob interface" do
      OpenChain::AllianceImagingClient.stub(:delay).and_return OpenChain::AllianceImagingClient
      OpenChain::AllianceImagingClient.should_receive(:consume_images)
      OpenChain::AllianceImagingClient.should_receive(:consume_stitch_responses)
      OpenChain::AllianceImagingClient.should_receive(:send_outstanding_stitch_requests)

      OpenChain::AllianceImagingClient.run_schedulable
    end
  end
end
