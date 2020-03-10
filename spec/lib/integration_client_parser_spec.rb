describe OpenChain::IntegrationClientParser do

  class FakeParser
    include OpenChain::IntegrationClientParser 

    def self.integration_folder
      raise "Mock me"
    end

    def self.parse_file_chunk a, b
      raise "Mock Me"
    end

  end

  subject { FakeParser }

  describe "process_past_days" do
    it "processes files from the previous few days, default options" do
      expect(subject).to receive(:delay).with({priority: 500}).and_return(subject).exactly(3)
      expect(subject).to receive(:process_day).with(DateTime.new(2018,8,6), { imaging: false, skip_delay:false })
      expect(subject).to receive(:process_day).with(DateTime.new(2018,8,7), { imaging: false, skip_delay:false })
      expect(subject).to receive(:process_day).with(DateTime.new(2018,8,8), { imaging: false, skip_delay:false })

      Timecop.freeze(Date.new(2018,8,8)) do
        subject.process_past_days 3
      end
    end

    it "processes files from the previous few days, no delay" do
      expect(subject).to receive(:process_day).with(DateTime.new(2018,8,7), { skip_delay:true })
      expect(subject).to receive(:process_day).with(DateTime.new(2018,8,8), { skip_delay:true })

      Timecop.freeze(Date.new(2018,8,8)) do
        subject.process_past_days 2, { skip_delay: true }
      end
    end
  end

  describe "process_day" do
    it "processes files from a specific day" do
      expect(subject).to receive(:integration_folder).and_return "the_folder"
      expect(OpenChain::S3).to receive(:integration_keys).with(Date.new(2018,8,8), "the_folder").and_yield("the_key").and_yield("the_key_2")
      expect(OpenChain::S3).to receive(:integration_bucket_name).and_return("the_bucket").twice
      expect(subject).to receive(:process_from_s3).with("the_bucket", "the_key", {imaging:false })
      expect(subject).to receive(:process_from_s3).with("the_bucket", "the_key_2", {imaging:false })

      subject.process_day Date.new(2018,8,8)
    end
  end

  describe "process_from_s3" do
    let(:s3_bucket) { "the_bucket" }
    let(:s3_path) { "2018-09/10/the_system/the_directory/the_file_name.1510174475.txt" }

    context "with parser that implements parse_file" do
      subject { 
        Class.new {
          include OpenChain::IntegrationClientParser

          def self.to_s
            "the_package_name::the_parser_name"
          end

          def self.parse_file file, log, opts

          end
        }
      }

      it "processes a file from S3 via parse_file" do
        data = "datafile"
        expect(OpenChain::S3).to receive(:get_data).with(s3_bucket, s3_path).and_return data
        expect(subject).to receive(:parse_file) do |param_data, param_log, param_opts|
          expect(param_data).to eq data
          expect(param_log).to be_instance_of(InboundFile)
          param_log.add_info_message "This is an info message"
          # This second one is a dupe and should be removed: we should have only one info message, not two.
          param_log.add_info_message "This is an info message"
          param_log.add_warning_message "No running by the pool"
          param_log.add_identifier "Order Number", "555666"
          expect(param_opts).to eq({ base_opt:"abc", bucket:s3_bucket, key:s3_path })
        end

        expect(subject).to receive(:post_process_data).with data

        Timecop.freeze(Date.new(2018,8,8)) do
          subject.process_from_s3(s3_bucket, s3_path, { base_opt:"abc" })
        end

        log = InboundFile.where(s3_bucket:s3_bucket, s3_path:s3_path).first
        expect(log).to_not be_nil
        expect(log.process_start_date).to eq(Date.new(2018,8,8))
        expect(log.process_end_date).to eq(Date.new(2018,8,8))
        expect(log.process_status).to eq(InboundFile::PROCESS_STATUS_WARNING)
        expect(log.parser_name).to eq("the_package_name::the_parser_name")
        expect(log.file_name).to eq("the_file_name.txt")
        expect(log.receipt_location).to eq("the_system/the_directory")

        expect(log.messages.length).to eq 2
        expect(log).to have_info_message "This is an info message"
        expect(log).to have_warning_message "No running by the pool"
        expect(log).to have_identifier "Order Number", "555666"
      end

      it "does not adjust the receipt location if the path doesn't match our standard archive prefixing" do
        data = "datafile"
        expect(OpenChain::S3).to receive(:get_data).and_return data
        subject.process_from_s3(s3_bucket, "some/path/to/file.txt", { base_opt:"abc" })

        log = InboundFile.where(s3_bucket:s3_bucket, s3_path:"some/path/to/file.txt").first
        expect(log).to_not be_nil
        expect(log.receipt_location).to eq("some/path/to/file.txt")
      end

      it "reprocesses a file from S3" do
        # Existing inbound file log record indicates that this is a document being reprocessed for the third time.
        existing_log = InboundFile.create!(s3_bucket:s3_bucket, s3_path:s3_path, requeue_count:2, original_process_start_date:Date.new(2006,6,6))
        original_process_start_date = existing_log.original_process_start_date

        data = "datafile"
        expect(OpenChain::S3).to receive(:get_data).with(s3_bucket, s3_path).and_return data
        expect(subject).to receive(:parse_file) do |param_data, param_log, param_opts|
          expect(param_data).to eq data
          expect(param_opts).to include({ base_opt:"abc", bucket:s3_bucket, key:s3_path })
          expect(param_log).to_not be_nil
          expect(param_log).to be_instance_of(InboundFile)
          param_log.add_info_message "This is an info message"
        end

        Timecop.freeze(Date.new(2018,8,8)) do
          subject.process_from_s3(s3_bucket, s3_path, { base_opt:"abc" })
        end

        logs = InboundFile.where(s3_bucket:s3_bucket, s3_path:s3_path)
        expect(logs.length).to eq 1
        log = logs.first
        expect(log.id).not_to eq existing_log.id
        expect(log.process_start_date).to eq(Date.new(2018,8,8))
        expect(log.process_status).to eq(InboundFile::PROCESS_STATUS_SUCCESS)
        expect(log.original_process_start_date).to eq(original_process_start_date)
        expect(log.requeue_count).to eq 3

        expect(log.messages.length).to eq 1
        expect(log).to have_info_message("This is an info message")
      end

      it "logs and throws exception" do
        expect(OpenChain::S3).to receive(:get_data).with(s3_bucket, s3_path).and_return "datafile"
        e = Exception.new("Oh the humanity")
        expect(subject).to receive(:parse_file).and_raise(e)
        expect(subject).to receive(:post_process_data).with "datafile"

        expect { subject.process_from_s3(s3_bucket, s3_path) }.to raise_error e

        log = InboundFile.where(s3_bucket:s3_bucket, s3_path:s3_path).first
        expect(log).to_not be_nil
        expect(log.process_status).to eq(InboundFile::PROCESS_STATUS_ERROR)
        expect(log.process_end_date).to_not be_nil

        expect(log.messages.length).to eq 1
        expect(log).to have_error_message "Oh the humanity"
      end

      it "handles UnreportedError" do
        expect(OpenChain::S3).to receive(:get_data).with(s3_bucket, s3_path).and_return "datafile"
        expect(subject).to receive(:parse_file).and_raise(UnreportedError.new("Oh the humanity"))

        expect{ subject.process_from_s3(s3_bucket, s3_path) }.not_to raise_error

        log = InboundFile.where(s3_bucket:s3_bucket, s3_path:s3_path).first
        expect(log).to_not be_nil
        expect(log.process_status).to eq(InboundFile::PROCESS_STATUS_ERROR)
        expect(log.process_end_date).to_not be_nil

        expect(log.messages.length).to eq 1
        expect(log).to have_error_message "Oh the humanity"
      end

      it "handles a LoggedParserRejectionError" do
        expect(OpenChain::S3).to receive(:get_data).with(s3_bucket, s3_path).and_return "datafile"
        expect(subject).to receive(:parse_file).and_raise(LoggedParserRejectionError.new("Oh the humanity"))

        expect{ subject.process_from_s3(s3_bucket, s3_path) }.not_to raise_error
        
        log = InboundFile.where(s3_bucket:s3_bucket, s3_path:s3_path).first
        expect(log).to_not be_nil
        expect(log.process_status).to eq(InboundFile::PROCESS_STATUS_SUCCESS)
        expect(log.process_end_date).to_not be_nil

        expect(log.messages.length).to eq 0
      end

      it "handles LoggedParserFatalError" do
        expect(OpenChain::S3).to receive(:get_data).with(s3_bucket, s3_path).and_return "datafile"
        e = LoggedParserFatalError.new("Oh the humanity")
        expect(subject).to receive(:parse_file).and_raise(e)

        expect { subject.process_from_s3(s3_bucket, s3_path) }.to raise_error e

        log = InboundFile.where(s3_bucket:s3_bucket, s3_path:s3_path).first
        expect(log).to_not be_nil
        expect(log.process_status).to eq(InboundFile::PROCESS_STATUS_SUCCESS)
        expect(log.process_end_date).to_not be_nil

        expect(log.messages.length).to eq 0
      end

      it "processes a file from S3 with logging disabled" do
        expect(OpenChain::S3).to receive(:get_data).with(s3_bucket, s3_path).and_return "datafile"
        expect(subject).to receive(:parse_file)

        # This should prevent the saving of a log record.
        expect(subject).to receive(:log_file?).and_return(false)

        subject.process_from_s3(s3_bucket, s3_path)

        expect(InboundFile.where(s3_bucket:s3_bucket, s3_path:s3_path).count).to eq 0
      end

      it "processes a file from S3 with log disable overridden by option value" do
        expect(OpenChain::S3).to receive(:get_data).with(s3_bucket, s3_path).and_return "datafile"
        expect(subject).to receive(:parse_file)

        # This would normally prevent the saving of a log record, but the force_inbound_file_logging option value
        # passed into the process method should force the save anyway.
        expect(subject).to receive(:log_file?).and_return(false)

        subject.process_from_s3(s3_bucket, s3_path, { force_inbound_file_logging: "Y" })

        expect(InboundFile.where(s3_bucket:s3_bucket, s3_path:s3_path).count).to eq 1
      end

      it "makes the inbound log available to the parser via an 'inbound_log' method" do

        p = Class.new do 
          include OpenChain::IntegrationClientParser

          def self.parse_file data, log, opts={}
            @inbound_file = inbound_file
            @instance_inbound_file = self.new.inbound_file
          end

          def self.log
            @inbound_file
          end

          def self.instance_inbound_file
            @instance_inbound_file
          end
        end
        expect(OpenChain::S3).to receive(:get_data).with(s3_bucket, s3_path).and_return "datafile"

        p.process_from_s3(s3_bucket, s3_path)
        # Verify both the class and instance method variants have access to the log
        expect(p.log).not_to be_nil
        expect(p.instance_inbound_file).not_to be_nil
        # The parser clears out the file after its finished parsing, so make sure it did that
        expect(p.inbound_file).to be_nil
        expect(p.log).to eq InboundFile.where(s3_bucket:s3_bucket, s3_path:s3_path).first
      end

      it "allows for data cleanup even if log finalization raises an error" do
        expect(OpenChain::S3).to receive(:get_data).with(s3_bucket, s3_path).and_return "datafile"
        expect(subject).to receive(:finalize_inbound_file_log).and_raise "Error"
        expect(subject).to receive(:post_process_data).with "datafile"
        
        expect { subject.process_from_s3 s3_bucket, s3_path }.to raise_error "Error"
      end

      it "ignores an empty file" do
        expect(OpenChain::S3).to receive(:get_data).with(s3_bucket, s3_path).and_return ""
        expect(subject).to_not receive(:parse_file)
        expect(subject).to_not receive(:post_process_data)

        subject.process_from_s3(s3_bucket, s3_path, { base_opt:"abc" })

        log = InboundFile.where(s3_bucket:s3_bucket, s3_path:s3_path).first
        expect(log.process_status).to eq(InboundFile::PROCESS_STATUS_SUCCESS)

        expect(log.messages.length).to eq 1
        expect(log).to have_info_message "Zero byte file was not processed."
      end

      it "ignores a nil file" do
        # This may not be possible in the wild.
        expect(OpenChain::S3).to receive(:get_data).with(s3_bucket, s3_path).and_return nil
        expect(subject).to_not receive(:parse_file)
        expect(subject).to_not receive(:post_process_data)

        subject.process_from_s3(s3_bucket, s3_path, { base_opt:"abc" })

        log = InboundFile.where(s3_bucket:s3_bucket, s3_path:s3_path).first
        expect(log.process_status).to eq(InboundFile::PROCESS_STATUS_SUCCESS)

        expect(log.messages.length).to eq 1
        expect(log).to have_info_message "Zero byte file was not processed."
      end

      it "processes an empty file if parser configured to allow it" do
        expect(subject).to receive(:process_zero_byte_files?).and_return(true).twice

        expect(OpenChain::S3).to receive(:get_data).with(s3_bucket, s3_path).and_return ""
        expect(subject).to receive(:parse_file)
        expect(subject).to receive(:post_process_data)

        subject.process_from_s3(s3_bucket, s3_path, { base_opt:"abc" })

        log = InboundFile.where(s3_bucket:s3_bucket, s3_path:s3_path).first
        expect(log.process_status).to eq(InboundFile::PROCESS_STATUS_SUCCESS)

        expect(log.messages.length).to eq 0
      end

      it "processes a file that cannot be assessed for length" do
        # Basically just testing that this doesn't cause a NoMethodError.
        expect(OpenChain::S3).to receive(:get_data).with(s3_bucket, s3_path).and_return Zip::InputStream.open(StringIO.new("Testing"))
        expect(subject).to receive(:parse_file)
        expect(subject).to receive(:post_process_data)

        subject.process_from_s3(s3_bucket, s3_path, { base_opt:"abc" })

        log = InboundFile.where(s3_bucket:s3_bucket, s3_path:s3_path).first
        expect(log.process_status).to eq(InboundFile::PROCESS_STATUS_SUCCESS)

        expect(log.messages.length).to eq 0
      end
    end

    context "with parser that implements parse" do
      subject { 
        Class.new {
          include OpenChain::IntegrationClientParser

          def self.to_s
            "the_package_name::the_parser_name"
          end

          def self.parse file, opts

          end
        }
      }

      it "processes a file from S3 via parse" do
        data = "datafile"
        expect(OpenChain::S3).to receive(:get_data).with(s3_bucket, s3_path).and_return data
        expect(subject).to receive(:parse) do |param_data, param_opts|
          expect(param_data).to eq data
          expect(param_opts).to include({ base_opt:"abc", bucket:s3_bucket, key:s3_path })
          param_log = param_opts[:log]
          expect(param_log).to_not be_nil
          expect(param_log).to be_instance_of(InboundFile)
          param_log.add_info_message "This is an info message"
        end

        Timecop.freeze(Date.new(2018,8,8)) do
          subject.process_from_s3(s3_bucket, s3_path, { base_opt:"abc" })
        end

        log = InboundFile.where(s3_bucket:s3_bucket, s3_path:s3_path).first
        expect(log).to_not be_nil
        expect(log.process_start_date).to eq(Date.new(2018,8,8))
        expect(log.process_status).to eq(InboundFile::PROCESS_STATUS_SUCCESS)
        expect(log.original_process_start_date).to eq(Date.new(2018,8,8))
        expect(log.requeue_count).to eq 0

        expect(log.messages.length).to eq 1
        expect(log).to have_info_message "This is an info message"
      end
    end

    context "with preprocessing data parser" do
      let (:data) { "File Contents" }
      let (:s3_bucket) { "bucket" }
      let (:s3_path) { "path" }

      before :each do 
        expect(OpenChain::S3).to receive(:get_data).with(s3_bucket, s3_path).and_return data
      end

      subject { 
        Class.new {
          include OpenChain::IntegrationClientParser

          def self.to_s
            "the_package_name::the_parser_name"
          end

          def self.pre_process_data data, opts
            nil
          end

          def self.parse file, opts

          end
        }
      }

      it "preprocesses data, passing the preprocessed data to the parse method" do
        expect(subject).to receive(:pre_process_data).with(data, {}).and_return "Preprocessed Data"
        expect(subject).to receive(:parse).with("Preprocessed Data", instance_of(Hash))
        subject.process_from_s3 s3_bucket, s3_path
      end

      it "does not replace data with nil if pre_process_data returns nil" do
        expect(subject).to receive(:pre_process_data) do |data, opts|
          # Mutate the string, and make sure the data passed to parse has the mutated value
          expect(opts).to eq({opts: true})
          data << " More Data"
          nil
        end

        expect(subject).to receive(:parse).with("File Contents More Data", instance_of(Hash))
        subject.process_from_s3 s3_bucket, s3_path, {opts: true}
      end
    end
  end

  describe "get_s3_key_without_timestamp" do
    it "strips timestamp from key" do
      expect(subject.get_s3_key_without_timestamp('file.1.2.3.1510174475.txt')).to eq('file.1.2.3.txt')
      expect(subject.get_s3_key_without_timestamp('file.1.2.3.txt')).to eq('file.1.2.txt')
      expect(subject.get_s3_key_without_timestamp('file.txt')).to eq('file.txt')
      expect(subject.get_s3_key_without_timestamp('file')).to eq('file')
      expect(subject.get_s3_key_without_timestamp('  ')).to eq('  ')
      expect(subject.get_s3_key_without_timestamp(nil)).to be_nil
    end
  end




  describe "delay_file_chunk_to_s3" do
    let (:parser) {
      Class.new do 
        include OpenChain::IntegrationClientParser

        def self.parse_file_chunk data, opts

        end
      end
    }

    let! (:ms) {
      stub_master_setup
    }

    let (:opts) { 
      {bucket: "bucket", key: "key"}
    }

    let (:upload_result) {
      d = instance_double("OpenChain::MockS3::UploadResult")
      allow(d).to receive(:bucket).and_return "temp_bucket"
      allow(d).to receive(:key).and_return "temp_key"
      d
    }

    it "saves file data to s3 and delays call to process_file_chunk_from_s3" do
      now = Time.zone.now
      expect(subject).to receive(:delay).and_return subject
      expect(subject).to receive(:parser_class_name).and_return "parser_class"
      expect(OpenChain::S3).to receive(:upload_data).with("chain-io-integration-temp", "test/parser_class/#{now.to_f}-file.txt", "Contents").and_return upload_result
      expect(subject).to receive(:process_file_chunk_from_s3).with("temp_bucket", "temp_key", opts, delete_from_s3: true, parse_method: :parse_file_chunk)
      Timecop.freeze(now) { 
        subject.delay_file_chunk_to_s3("/path/to/file.txt", "Contents", opts)
      }
    end

    it "strips InboundFile from opts" do
      opts[:log] = InboundFile.new

      expect(subject).to receive(:delay).and_return subject
      expect(subject).to receive(:parser_class_name).and_return "parser_class"
      expect(OpenChain::S3).to receive(:upload_data).and_return upload_result

      expect(subject).to receive(:process_file_chunk_from_s3) do |bucket, key, parse_opts, method_opts|
        expect(parse_opts).to eq({bucket: "bucket", key: "key"})
      end

      subject.delay_file_chunk_to_s3("/path/to/file.txt", "Contents", opts)
    end
  end

  describe "process_file_chunk_from_s3" do

    let (:opts) { 
      {bucket: "bucket", key: "key"}
    }

    it "retrieves data from s3, calls parser method, and deletes data" do
      expect(subject).to receive(:parse_file_chunk).with "Downloaded Data", opts
      expect(subject).to receive(:retrieve_file_data).with("bucket", "key", opts).and_return "Downloaded Data"
      expect(OpenChain::S3).to receive(:delete).with "bucket", "key"

      subject.process_file_chunk_from_s3 "bucket", "key", opts
    end

    class FakeDoFileParser < FakeParser
      def self.do_file a, b
        raise "Mock Me"
      end
    end

    it "can use a diffrent parse method" do
      expect(FakeDoFileParser).to receive(:do_file).with "Downloaded Data", opts
      expect(FakeDoFileParser).to receive(:retrieve_file_data).with("bucket", "key", opts).and_return "Downloaded Data"
      expect(OpenChain::S3).to receive(:delete).with "bucket", "key"

      FakeDoFileParser.process_file_chunk_from_s3 "bucket", "key", opts, parse_method: :do_file     
    end

    it "does not delete file if instructed" do
      expect(subject).to receive(:parse_file_chunk).with "Downloaded Data", opts
      expect(subject).to receive(:retrieve_file_data).with("bucket", "key", opts).and_return "Downloaded Data"
      expect(OpenChain::S3).not_to receive(:delete)

      subject.process_file_chunk_from_s3 "bucket", "key", opts, delete_from_s3: false
    end

    it "does not delete from s3 if an error is raised" do
      expect(subject).to receive(:parse_file_chunk).and_raise "Error"
      expect(subject).to receive(:retrieve_file_data).with("bucket", "key", opts).and_return "Downloaded Data"
      expect(OpenChain::S3).not_to receive(:delete)

      expect { subject.process_file_chunk_from_s3 "bucket", "key", opts }.to raise_error "Error"
    end
  end
end