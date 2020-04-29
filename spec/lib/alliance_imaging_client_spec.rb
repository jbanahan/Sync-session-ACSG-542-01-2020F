describe OpenChain::AllianceImagingClient do

  let! (:master_setup) { stub_master_setup }

  describe "bulk_request_images" do
    before :each do
      @e1 = Factory(:entry, :broker_reference=>'123456', :source_system=>'Alliance')
      @e2 = Factory(:entry, :broker_reference=>'654321', :source_system=>'Alliance')
      @e3 = Factory(:entry, :broker_reference=>'777777', :source_system=>'Fenix')
    end
    it 'should request based on primary keys' do
      expect(OpenChain::AllianceImagingClient).to receive(:request_images).with('123456')
      expect(OpenChain::AllianceImagingClient).to receive(:request_images).with('654321')
      OpenChain::AllianceImagingClient.bulk_request_images primary_keys: [@e1.id, @e2.id]
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
      @e1 = Factory(:entry, :broker_reference=>'123456', :source_system=>'Alliance')
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
      response = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user
      expect(response[:entry]).to eq @e1
      expect(response[:entry].attachments[0].is_private).to be_falsey
    end

    it 'should be private if doc_desc starts with "private"' do
      @hash["doc_desc"] = "private_attachment"
      r = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user
      expect(r[:entry].attachments[0].is_private).to be_truthy
    end

    it 'should load an attachment into the entry with the proper content type' do
      now = Time.zone.parse("2018-08-01 12:00")
      r = nil
      Timecop.freeze(now) do
        r = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user
      end

      att = r[:attachment]
      expect(att).not_to be_nil

      expect(att.attached_content_type).to eq("application/pdf")
      expect(att.attachment_type).to eq(@hash["doc_desc"])
      expect(att.source_system_timestamp).not_to be_nil
      expect(att.alliance_suffix).to eq "345"
      expect(att.alliance_revision).to eq 12

      expect(r[:entry]).to eq @e1
      expect(r[:entry].attachments.size).to eq(1)
      # Make sure the entry was touched
      expect(r[:entry].updated_at).to eq now
    end

    it 'should look for source_system in the message hash and use entry number to lookup for Fenix source system' do
      @hash["source_system"] = 'Fenix'
      @e1.update_attributes :source_system => 'Fenix', :entry_number => "#{@hash['file_number']}", :broker_reference => '654321'

      r = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user

      expect(r[:entry]).to eq @e1
      expect(r[:entry].attachments.size).to eq(1)

      expect(r[:attachment].attached_content_type).to eq("application/pdf")
      expect(r[:attachment].attachment_type).to eq(@hash["doc_desc"])
      expect(r[:attachment].source_system_timestamp).not_to be_nil
    end

    it 'should generate shell entry records when an entry is missing and the source system is Fenix' do
      # These are the only hash values we should currently expect from the Fenix imaging monitoring process
      @hash = {"source_system" => "Fenix", "file_number" => "123456", "doc_date" => Time.now, "file_name"=>"file.pdf", "doc_desc" => "Source Testing"}
      expect(Lock).to receive(:acquire).with("Entry-Fenix-123456").and_yield
      r = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user
      entry = r[:entry]
      attachment = r[:attachment]

      expect(entry.entry_number).to eq(@hash["file_number"])
      expect(entry.source_system).to eq('Fenix')
      expect(entry.file_logged_date).to be >= (Time.zone.now - 1.minute)

      expect(entry.attachments.size).to eq(1)
      expect(attachment.attached_content_type).to eq("application/pdf")
      expect(attachment.attached_file_name).to eq("file.pdf")
      expect(attachment.attachment_type).to eq(@hash["doc_desc"])
      expect(attachment.source_system_timestamp).not_to be_nil
    end

    it 'should generate shell entry records when an entry is missing and the source system is Alliance' do
      @e1.destroy
      expect(Lock).to receive(:acquire).with("Entry-Alliance-123456").and_yield
      r = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user

      entry = r[:entry]
      attachment = r[:attachment]

      expect(entry.broker_reference).to eq(@hash["file_number"])
      expect(entry.source_system).to eq('Alliance')
      expect(entry.file_logged_date).to be_nil

      expect(entry.attachments.size).to eq(1)
      expect(attachment.attached_content_type).to eq("application/pdf")
      expect(attachment.attached_file_name).to eq("file.pdf")
      expect(attachment.attachment_type).to eq(@hash["doc_desc"])
      expect(attachment.source_system_timestamp).not_to be_nil
    end

    it "skips alliance files that already have revisions higher than the one received" do
      @hash['suffix'] = '00000'

      existing = @e1.attachments.create! alliance_suffix: '000', alliance_revision: 1, attachment_type: @hash['doc_desc']

      r = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user
      expect(r).to be_nil
      expect(@e1.attachments.size).to eq 1
      expect(@e1.attachments.first).to eq existing
    end

    it "deletes previous versions of the same attachment type / alliance suffix type" do
      existing = @e1.attachments.create! alliance_suffix: '000', alliance_revision: 0, attachment_type: @hash['doc_desc']

      @hash['suffix'] = '01000'
      r = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user

      entry = r[:entry]
      attachment = r[:attachment]

      expect(attachment.attached_file_name).to eq "file.pdf"
      expect(attachment.alliance_revision).to eq 1
      expect(entry.attachments.first).not_to eq existing

    end

    it "if suffix and revision are the same, it keeps the newest document" do
      @hash['suffix'] = '01000'

      # The existing document is newer, so it should be kept
      existing = @e1.attachments.create! alliance_suffix: '000', alliance_revision: 1, attachment_type: @hash['doc_desc'], source_system_timestamp: Time.zone.parse("2016-03-01 00:00")

      r = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user

      expect(r).to be_nil
      expect(@e1.attachments.size).to eq 1
      expect(@e1.attachments.first).to eq existing
    end

    it "keeps the image from the request if its newer than an existing document with the same type/revision" do
      @hash['suffix'] = '01000'

      # The existing document is newer, so it should be kept
      existing = @e1.attachments.create! alliance_suffix: '000', alliance_revision: 1, attachment_type: @hash['doc_desc'], source_system_timestamp: Time.zone.parse("2015-03-01 00:00")

      r = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user

      entry = r[:entry]
      attachment = r[:attachment]

      expect(attachment.attached_file_name).to eq "file.pdf"
      expect(attachment.alliance_revision).to eq 1
      expect(entry.attachments.first).not_to eq existing
    end

    it "snapshots the entry" do
      r = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user
      entry = r[:entry]
      expect(entry.entity_snapshots.length).to eq 1
      expect(entry.entity_snapshots.first.context).to eq "Imaging"
    end

    it "ensures the file_number value in the hash is a string" do
      # This might seem weird that I'm mocking out an ActiveRecord call, but it's important because if the file number isn't a string, the
      # DB index on broker_reference / entry_number isn't utilized.
      # This test ensures there's a check to make sure the file number is stringified.
      mock_relation = double("ActiveRecord::Relation")
      expect(mock_relation).to receive(:first).and_return @e1
      expect(Entry).to receive(:where).with({source_system: "Alliance", broker_reference: "123456"}).and_return mock_relation

      @hash["file_number"] = 123456.0

      r = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user
    end

    context "Fenix B3 Files" do
      before :each do
        @hash["source_system"] = 'Fenix'
        @e1.update_attributes :source_system => 'Fenix', :entry_number => "#{@hash['file_number']}", :broker_reference => '654321'
        @hash["doc_desc"] = "Automated"
      end

      it "should recognize B3 Automated Fenix files and attach the images as B3 records" do
        @hash['file_name'] = "File_cdc_123128.pdf"
        r = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user

        entry = r[:entry]
        attachment = r[:attachment]

        expect(entry.attachments.size).to eq(1)
        expect(attachment.attached_file_name).to eq(@hash['file_name'])
        expect(attachment.attachment_type).to eq("B3")
      end

      it "should retain only 1 B3 attachment" do
        existing = @e1.attachments.build
        existing.attached_file_name = "existing.pdf"
        existing.attachment_type = "B3"
        existing.save

        @hash['file_name'] = "File_cdc_123128.pdf"
        r = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user

        entry = r[:entry]
        attachment = r[:attachment]

        expect(entry.attachments.length).to eq(1)
        expect(entry.attachments.first).not_to eq existing
        expect(attachment.attached_file_name).to eq(@hash['file_name'])
        expect(attachment.attachment_type).to eq("B3")
      end

      it "should recognize RNS Automated Fenix files and attach the images as RNS records" do
        @hash['file_name'] = "File_rns_123128.pdf"
        r = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user

        entry = r[:entry]
        attachment = r[:attachment]

        expect(entry.attachments.size).to eq(1)
        expect(attachment.attached_file_name).to eq(@hash['file_name'])
        expect(attachment.attachment_type).to eq("Customs Release Notice")
      end

      it "should retain only 1 RNS attachment" do
        existing = @e1.attachments.build
        existing.attached_file_name = "existing.pdf"
        existing.attachment_type = "Customs Release Notice"
        existing.save

        @hash['file_name'] = "File_rns_123128.pdf"
        r = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user

        entry = r[:entry]
        attachment = r[:attachment]

        expect(entry.attachments.size).to eq(1)
        expect(entry.attachments.first).not_to eq existing
        expect(attachment.attached_file_name).to eq(@hash['file_name'])
        expect(attachment.attachment_type).to eq("Customs Release Notice")
      end

      it "should recognize B3 Recap Automated Fenix files and attach the images as recap records" do
        @hash['file_name'] = "File_recap_123128.pdf"
        r = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user

        entry = r[:entry]
        attachment = r[:attachment]

        expect(entry.attachments.size).to eq(1)
        expect(attachment.attached_file_name).to eq(@hash['file_name'])
        expect(attachment.attachment_type).to eq("B3 Recap")
      end

      it "should retain only 1 recap attachment" do
        existing = @e1.attachments.build
        existing.attached_file_name = "existing.pdf"
        existing.attachment_type = "B3 Recap"
        existing.save

        @hash['file_name'] = "File_recap_123128.pdf"
        r = OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash, user

        entry = r[:entry]
        attachment = r[:attachment]

        expect(entry.attachments.size).to eq(1)
        expect(entry.attachments.first).not_to eq existing
        expect(attachment.attached_file_name).to eq(@hash['file_name'])
        expect(attachment.attachment_type).to eq("B3 Recap")
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
      {"sqs_receive_queue" => "sqs"}
    }

    let (:tempfile) {
      # Have to use a double here rather than a class_double because Tempfile is stupid
      # and delegates method calls to and internal File object...which means it doesn't technically
      # implement the File methods and the rspec mocks complains if you try and use class_double and mock
      # an actual tempfile.
      t = double(Tempfile)
      allow(t).to receive(:length).and_return 1
      t
    }

    let (:hash) { {"file_name" => "file.txt", "s3_bucket" => "bucket", "s3_key" => "key"} }

    before :each do
      allow(OpenChain::AllianceImagingClient).to receive(:imaging_config).and_return config
    end

    it "should use SQS queue to download messages and use the S3 client with tempfile to download the file" do
      # This is mostly just mocks, but I wanted to ensure the expected calls are actually happening
      expect(OpenChain::SQS).to receive(:poll).with("sqs", visibility_timeout: 300).and_yield hash
      expect(OpenChain::S3).to receive(:download_to_tempfile).with(hash["s3_bucket"], hash["s3_key"], {}).and_return(tempfile)
      expect(OpenChain::AllianceImagingClient).to receive(:process_image_file).with(tempfile, hash, user)
      expect(OpenChain::S3).to receive(:zero_file).with(hash["s3_bucket"], hash["s3_key"])

      OpenChain::AllianceImagingClient.consume_images
    end

    it "passes s3 version if present" do
      # This is mostly just mocks, but I wanted to ensure the expected calls are actually happening
      hash["s3_version"] = "version"
      expect(OpenChain::SQS).to receive(:poll).with("sqs", visibility_timeout: 300).and_yield hash
      expect(OpenChain::S3).to receive(:download_to_tempfile).with(hash["s3_bucket"], hash["s3_key"], {version: "version"}).and_return(tempfile)
      expect(OpenChain::AllianceImagingClient).to receive(:process_image_file).with(tempfile, hash, user)
      expect(OpenChain::S3).to receive(:zero_file).with(hash["s3_bucket"], hash["s3_key"])

      OpenChain::AllianceImagingClient.consume_images
    end

    it "handles errors and retries polling" do
      error = StandardError.new
      expect(OpenChain::SQS).to receive(:poll).exactly(10).times.and_raise error
      expect(error).to receive(:log_me).with(["Alliance imaging client hash: null"]).exactly(10).times

      OpenChain::AllianceImagingClient.consume_images
    end

    it "skips zero-length files" do
      t = double(Tempfile)
      expect(t).to receive(:length).and_return 0

      expect(OpenChain::SQS).to receive(:poll).with("sqs", visibility_timeout: 300).and_yield hash
      expect(OpenChain::S3).to receive(:download_to_tempfile).with(hash["s3_bucket"], hash["s3_key"], {}).and_return(t)
      expect(OpenChain::AllianceImagingClient).not_to receive(:process_image_file)

      OpenChain::AllianceImagingClient.consume_images
    end

    context "with fenix document proxy enabled" do
      before :each do
        allow(master_setup).to receive(:custom_feature?).with("Proxy Fenix Drive Docs").and_return true
      end

      let (:entry) { Entry.new source_system: Entry::FENIX_SOURCE_SYSTEM }
      let (:attachment) { Attachment.new }
      let (:tempfile) {
        # Have to use a double here rather than a class_double because Tempfile is stupid
        # and delegates method calls to and internal File object...which means it doesn't technically
        # implement the File methods and the rspec mocks complains if you try and use class_double and mock
        # an actual tempfile.
        t = double(Tempfile)
        allow(t).to receive(:length).and_return 1
        t
      }

      before :each do
        hash['export_process'] = "Canada Google Drive"

        allow(OpenChain::SQS).to receive(:poll).with("sqs", visibility_timeout: 300).and_yield hash
        allow(OpenChain::S3).to receive(:download_to_tempfile).with(hash["s3_bucket"], hash["s3_key"], {}).and_return(tempfile)
      end

      it "calls proxy docs method for fenix docs" do
        expect(described_class).to receive(:process_image_file).with(tempfile, hash, user).and_return({entry: entry, attachment: attachment})
        expect(described_class).to receive(:proxy_fenix_drive_docs).with(entry, hash)

        described_class.consume_images
      end

      it 'does not call proxy docs if message is not google drive docs' do
        hash['export_process'] = "Not Canada Google Drive"
        expect(described_class).to receive(:process_image_file).with(tempfile, hash, user).and_return({entry: entry, attachment: attachment})
        expect(described_class).not_to receive(:proxy_fenix_drive_docs)
        expect(OpenChain::S3).to receive(:zero_file).with(hash["s3_bucket"], hash["s3_key"])

        described_class.consume_images
      end

      it 'does not call proxy docs if message is not for Fenix entry' do
        entry.source_system = "Not Fenix"
        expect(described_class).to receive(:process_image_file).with(tempfile, hash, user).and_return({entry: entry, attachment: attachment})
        expect(described_class).not_to receive(:proxy_fenix_drive_docs)
        expect(OpenChain::S3).to receive(:zero_file).with(hash["s3_bucket"], hash["s3_key"])

        described_class.consume_images
      end

      it 'does not call proxy docs if custom feature is not enabled' do
        expect(master_setup).to receive(:custom_feature?).with("Proxy Fenix Drive Docs").and_return false
        expect(described_class).to receive(:process_image_file).with(tempfile, hash, user).and_return({entry: entry, attachment: attachment})
        expect(described_class).not_to receive(:proxy_fenix_drive_docs)
        expect(OpenChain::S3).to receive(:zero_file).with(hash["s3_bucket"], hash["s3_key"])

        described_class.consume_images
      end

      it 'does not call proxy docs if process image file returns nil' do
        expect(described_class).to receive(:process_image_file).with(tempfile, hash, user).and_return nil
        expect(described_class).not_to receive(:proxy_fenix_drive_docs)
        expect(OpenChain::S3).to receive(:zero_file).with(hash["s3_bucket"], hash["s3_key"])

        described_class.consume_images
      end
    end
  end

  describe "proxy_fenix_drive_docs" do
    let (:entry) { Entry.new customer_number: "TEST" }
    let (:config) { {'TEST' => {"queue" => "queue1"}}}
    let (:message) { {"message" => "message"}}

    it "forwards message to queue configured for customer" do
      expect(described_class).to receive(:proxy_fenix_drive_docs_config).and_return config
      expect(OpenChain::SQS).to receive(:send_json).with("queue1", message)

      described_class.proxy_fenix_drive_docs entry, message
    end

    it "forwards message to multiple queues configured for customer" do
      config["TEST"]["queue"] = ["queue1", "queue2"]
      expect(described_class).to receive(:proxy_fenix_drive_docs_config).and_return config
      expect(OpenChain::SQS).to receive(:send_json).with("queue1", message)
      expect(OpenChain::SQS).to receive(:send_json).with("queue2", message)

      described_class.proxy_fenix_drive_docs entry, message
    end

    it "does not forward message if customer is not configured for proxy" do
      entry.customer_number = "CUST"
      expect(described_class).to receive(:proxy_fenix_drive_docs_config).and_return config
      expect(OpenChain::SQS).not_to receive(:send_json)

      described_class.proxy_fenix_drive_docs entry, message
    end
  end

  describe "run_schedulable" do

    it "implements SchedulableJob interface" do
      allow(OpenChain::AllianceImagingClient).to receive(:delay).and_return OpenChain::AllianceImagingClient
      expect(OpenChain::AllianceImagingClient).to receive(:consume_images)

      OpenChain::AllianceImagingClient.run_schedulable
    end

    it "does not call consume_images if 2 jobs are already running" do
      expect(OpenChain::AllianceImagingClient).to receive(:queued_jobs_for_method).with(OpenChain::AllianceImagingClient, :consume_images).and_return 2

      allow(OpenChain::AllianceImagingClient).to receive(:delay).and_return OpenChain::AllianceImagingClient
      expect(OpenChain::AllianceImagingClient).not_to receive(:consume_images)
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
      now = Time.zone.parse("2018-08-01 12:00")
      expect(Lock).to receive(:acquire).with("Entry-Fenix-11981001795105").and_yield
      expect(Lock).to receive(:with_lock_retry).with(instance_of(Entry)).and_yield
      r = nil
      Timecop.freeze(now) do
        r = OpenChain::AllianceImagingClient.process_fenix_nd_image_file @tempfile, @message, user
      end
      entry = r[:entry]

      expect(entry).not_to be_nil
      expect(entry.entry_number).to eq "11981001795105"
      expect(entry.source_system).to eq "Fenix"
      expect(entry.file_logged_date).to eq now
      expect(entry.updated_at).to eq now

      a = r[:attachment]
      expect(a).not_to be_nil
      expect(a.attachment_type).to eq "B3"
      expect(a.source_system_timestamp).to eq Time.zone.parse("2015-09-04T05:30:35-10:00")
      expect(a.is_private).to be_nil
      # Note the check on the absence of the leading underscore
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

      r = OpenChain::AllianceImagingClient.process_fenix_nd_image_file @tempfile, @message, user
      e = r[:entry]
      expect(e.attachments.size).to eq 2
      expect(e.attachments.map {|a| a.attached_file_name }.uniq).to eq ["11981001795105 _B3_01092015 14.24.42 PM.pdf"]
    end

    it "replaces previous versions of B3 attachment" do
      e = Factory(:entry, entry_number: "11981001795105", source_system: "Fenix")
      e.attachments.create! attachment_type: "B3", source_system_timestamp: "2015-09-04T04:30:35-10:00"
      e.attachments.create! attachment_type: "B3", source_system_timestamp: "2015-09-04T03:30:35-10:00"

      r = OpenChain::AllianceImagingClient.process_fenix_nd_image_file @tempfile, @message, user
      e = r[:entry]
      expect(e.attachments.size).to eq 1
      expect(e.attachments.first.attached_file_name).to eq "11981001795105 _B3_01092015 14.24.42 PM.pdf"
      expect(r[:attachment].attached_file_name).to eq "11981001795105 _B3_01092015 14.24.42 PM.pdf"
    end

    it "does not save files that have newer versions attached to the entry" do
      e = Factory(:entry, entry_number: "11981001795105", source_system: "Fenix")
      e.attachments.create! attachment_type: "B3", source_system_timestamp: "2015-09-05T04:30:35-10:00", attached_file_name: "file.pdf"

      r = OpenChain::AllianceImagingClient.process_fenix_nd_image_file @tempfile, @message, user
      expect(r).to be_nil

      e.reload
      expect(e.attachments.size).to eq 1
      expect(e.attachments.first.attached_file_name).to eq "file.pdf"
    end

    it "replaces previous versions of RNS attachment" do
      @message['doc_desc'] = "RNS"
      e = Factory(:entry, entry_number: "11981001795105", source_system: "Fenix")
      e.attachments.create! attachment_type: "RNS", source_system_timestamp: "2015-09-04T04:30:35-10:00"

      r = OpenChain::AllianceImagingClient.process_fenix_nd_image_file @tempfile, @message, user
      e = r[:entry]
      expect(e.attachments.size).to eq 1
      expect(e.attachments.first.attached_file_name).to eq "11981001795105 _B3_01092015 14.24.42 PM.pdf"
      expect(r[:attachment].attached_file_name).to eq "11981001795105 _B3_01092015 14.24.42 PM.pdf"
    end

    it "replaces previous versions of B3 Recap attachment" do
      @message['doc_desc'] = "B3 Recap"
      e = Factory(:entry, entry_number: "11981001795105", source_system: "Fenix")
      e.attachments.create! attachment_type: "B3 Recap", source_system_timestamp: "2015-09-04T04:30:35-10:00"

      r = OpenChain::AllianceImagingClient.process_fenix_nd_image_file @tempfile, @message, user
      e = r[:entry]
      expect(e.attachments.size).to eq 1
      expect(e.attachments.first.attached_file_name).to eq "11981001795105 _B3_01092015 14.24.42 PM.pdf"
      expect(r[:attachment].attached_file_name).to eq "11981001795105 _B3_01092015 14.24.42 PM.pdf"
    end

    it 'replaces previous versions of billing invoices' do
      @message['doc_desc'] = "Invoice"
      @message['file_name'] = "invoice 123.pdf"
      e = Factory(:entry, entry_number: "11981001795105", source_system: "Fenix")
      a1 = e.attachments.create! attachment_type: "Invoice", source_system_timestamp: "2015-09-04T04:30:35-10:00", attached_file_name: "invoice 123.pdf"
      e.attachments.create! attachment_type: "Invoice", source_system_timestamp: "2015-09-04T04:30:35-10:00", attached_file_name: "invoice 345.pdf"

      r = OpenChain::AllianceImagingClient.process_fenix_nd_image_file @tempfile, @message, user
      e = r[:entry]
      expect(e.attachments.size).to eq 2
      expect(e.attachments.map {|a| a.attached_file_name}.sort).to eq ["invoice 123.pdf", "invoice 345.pdf"]
      # make sure the new file referenced by message was the one that got created, and the existing one got removed
      expect(e.attachments).not_to include a1
      expect(r[:attachment].attached_file_name).to eq "invoice 123.pdf"
    end

    it "replaces previous versions of B3 Recap attachment" do
      @message['doc_desc'] = "Cartage Slip"
      e = Factory(:entry, entry_number: "11981001795105", source_system: "Fenix")
      e.attachments.create! attachment_type: "Cartage Slip", source_system_timestamp: "2015-09-04T04:30:35-10:00"

      r = OpenChain::AllianceImagingClient.process_fenix_nd_image_file @tempfile, @message, user
      e = r[:entry]

      expect(e.attachments.size).to eq 1
      expect(e.attachments.first.attached_file_name).to eq "11981001795105 _B3_01092015 14.24.42 PM.pdf"
    end

    it "accepts 1 as a value for public attachments" do
      @message["public"] = "1"
      r = OpenChain::AllianceImagingClient.process_fenix_nd_image_file @tempfile, @message, user
      expect(r[:attachment].is_private).to be_nil
    end

    it "uses any other value of 'public' other than true/1 to make the attachment private" do
      @message["public"] = ""
      r = OpenChain::AllianceImagingClient.process_fenix_nd_image_file @tempfile, @message, user
      expect(r[:attachment].is_private).to eq true
    end

    it "ensures the file_number value in the hash is a string" do
      # This might seem weird that I'm mocking out an ActiveRecord call, but it's important because if the file number isn't a string, the
      # DB index on broker_reference / entry_number isn't utilized.
      # This test ensures there's a check to make sure the file number is stringified.
      entry = Factory(:entry)
      mock_relation = double("ActiveRecord::Relation")
      expect(mock_relation).to receive(:first_or_create!).and_return entry
      expect(Entry).to receive(:where).with({source_system: "Fenix", entry_number: "11981001795105"}).and_return mock_relation

      @message["file_number"] = 11981001795105.0

      r = OpenChain::AllianceImagingClient.process_fenix_nd_image_file @tempfile, @message, user
    end

    it "strips trailing underscores from the filename" do
      @message["file_name"] = @message["file_name"] + "_"

      r = OpenChain::AllianceImagingClient.process_fenix_nd_image_file @tempfile, @message, user
      a = r[:attachment]

      expect(a.attached_file_name).to eq "11981001795105 _B3_01092015 14.24.42 PM.pdf"
    end

  end

  describe "request_images" do
    subject { described_class }
    let (:secrets) {
      {
        "kewill_imaging" => {
          "sqs_send_queue" => "send_queue",
          "s3_bucket" => "bucket",
          "sqs_receive_queue" => "queue"
        }
      }
    }

    let! (:ms) {
      ms = stub_master_setup
      allow(MasterSetup).to receive(:secrets).and_return secrets
      ms
    }

    context "without custom feature enabled" do
      before :each do
        expect(ms).to receive(:custom_feature?).with("Kewill Imaging Request Queue").and_return false
      end

      it "calls legacy request if custom feature is not enabled" do
        expect(OpenChain::SQS).to receive(:send_json).with("send_queue", {"file_number"=> "12345", "sqs_queue" => "queue", "s3_bucket" => "bucket"}, {opts: 1})
        described_class.request_images("12345", {opts: 1})
      end
    end

    context "with custom feature enabled" do
      before :each do
        expect(ms).to receive(:custom_feature?).with("Kewill Imaging Request Queue").and_return true
      end

      it "calls DocumentRequestQueueItem if custom feature is enabled" do
        expect(DocumentRequestQueueItem).to receive(:enqueue_kewill_document_request).with("12345", request_delay_minutes: nil)
        described_class.request_images("12345", {opts: 1})
      end
    end
  end
end
