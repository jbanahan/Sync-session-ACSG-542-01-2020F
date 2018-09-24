describe OpenChain::IntegrationClientParser do

  subject { Class.new { include OpenChain::IntegrationClientParser } }

  describe "process_past_days" do
    it "processes files from the previous few days, default options" do
      expect(subject).to receive(:delay).with({priority: 500}).and_return(subject.class).exactly(3)
      expect(subject.class).to receive(:process_day).with(DateTime.new(2018,8,6), { imaging: false, skip_delay:false })
      expect(subject.class).to receive(:process_day).with(DateTime.new(2018,8,7), { imaging: false, skip_delay:false })
      expect(subject.class).to receive(:process_day).with(DateTime.new(2018,8,8), { imaging: false, skip_delay:false })

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
    let(:s3_path) { "the_directory/the_file_name.1510174475.txt" }

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
        expect(log.receipt_location).to eq("the_directory")

        expect(log.messages.length).to eq 2
        expect(log).to have_info_message "This is an info message"
        expect(log).to have_warning_message "No running by the pool"
        expect(log).to have_identifier "Order Number", "555666"
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
end