module Helpers

  # Use this method when you need to evaluate a full excel row as an array
  # There's some underlying comparison that fails when comparing arrays
  # and using an excel date 
  #
  # ie. sheet.row(0) == [excel_date(Date.new(2013, 1, 1))]
  def excel_date date
    #Excel internally stores date values as days since Jan 1, 1900
    excel_start_date = Date.new(1899, 12, 30).jd
    (date.jd - excel_start_date).to_f
  end

  def stub_paperclip
    # Stub out the actual paperclip save/destroy method, which is what pushes/deletes the files to/from S3
    # Everything else about the attachment process should remain working, the attached_* attributes should
    # be filled in when 'attachment.attached = file' is used, etc.  only difference is no s3 calls should be made
    # ever.
    allow_any_instance_of(Paperclip::Attachment).to receive(:save).and_return true
    allow_any_instance_of(Paperclip::Attachment).to receive(:destroy).and_return true
  end

  def stub_snapshots
    EntitySnapshot.snapshot_writer_impl = FakeSnapshotWriterImpl
  end

  def unstub_snapshots
    EntitySnapshot.snapshot_writer_impl = EntitySnapshot::DefaultSnapshotWriterImpl
  end

  def extract_excel_from_email email, attachment_name
    attachment = email.attachments[attachment_name]
    return nil if attachment.nil?

    Spreadsheet.open(StringIO.new(attachment.read))
  end

  class MockS3
    class AwsErrors < StandardError; end
    class NoSuchKeyError < AwsErrors; end 

    def self.parse_full_s3_path path
      # We're expecting the path to be like "/bucket/path/to/file.pdf"
      # The first path segment of the file is the bucket, everything after that is the path to the actual file
      split_path = path.split("/")
      
      # If the path started with a / the first index is blank
      split_path.shift if split_path[0].strip.length == 0

      [split_path[0], split_path[1..-1].join("/")]
    end
    def self.bucket_name name = Rails.env
      h = {:production=>"prodname", :development=>'devname', :test=>'testname'}
      h[name]
    end
    def self.integration_bucket_name
      "mock_bucket_name"
    end
    def self.method_missing(sym, *args, &block)
      raise "Mock S3 method #{sym} not implemented, you must stub it yourself or include the `s3: true` tag on your test to use the real implementation."
    end
    def method_missing(sym, *args, &block)
      raise "Mock S3 method #{sym} not implemented, you must stub it yourself or include the `s3: true` tag on your test to use the real implementation."
    end

    def self.url_for bucket, path, expires_in, options = {}
      "http://#{bucket}.s3.com/#{path}?expires_in=#{expires_in.to_i}"
    end
    
    def self.upload_data bucket_name, path, data
      # Handle a couple different valid data objects
      local_data = nil
      if data.respond_to?(:read)
        local_data = data.read
      elsif data.is_a?(Pathname)
        local_data = IO.read data.to_s
      else
        local_data = data
      end

      @version_id += 1
      @datastore[key(bucket_name, path, @version_id)] = local_data

      UploadResult.new bucket_name, path, @version_id.to_s
    end

    class UploadResult

      attr_reader :bucket, :key, :version

      def initialize bucket, key, version
        @bucket = bucket
        @key = key
        @version = version
      end
    end

    def self.get_versioned_data bucket, path, version, io = nil
      local_data = @datastore[key(bucket, path, version)]

      if io
        io.write local_data
        io.flush
        io.rewind
        nil
      else
        local_data
      end
    end

    def self.key bucket, path, version
      "#{bucket}~#{path}~#{version}"
    end

    def self.reset
      @datastore = {}
      @version_id = 0
    end
  end

  # Stub out the S3 methods
  def stub_s3
    #hold the old S3 class for later
    @old_stub_s3_class = OpenChain::S3
    
    # First, completely undefine the class
    OpenChain.send(:remove_const,:S3)
  
    MockS3.reset

    # set the new constant in the module
    OpenChain.const_set(:S3,MockS3)
  end

  def stub_email_logging
    allow_any_instance_of(OpenMailer).to receive(:log_email).and_return true
  end

  def unstub_s3
    MockS3.reset

    OpenChain.send(:remove_const,:S3)
    OpenChain.const_set(:S3,@old_stub_s3_class)
  end
  
  def allow_api_access user
    use_json
    allow_api_user user
  end

  def allow_api_user user
    request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Token.encode_credentials "#{user.username}:#{user.api_auth_token}"
  end

  def use_json
    request.env['CONTENT_TYPE'] = 'application/json'
    request.env['HTTP_ACCEPT'] = 'application/json'
  end

  def stub_event_publisher
    allow(OpenChain::EventPublisher).to receive(:publish).and_return nil
  end

  def retry_expect retry_count: 2, retry_wait: 1, additional_rescue_from: []
    # Allow for capturing and retrying when the expectations run in the block errors from other errors as well
    rescue_from = additional_rescue_from.dup
    rescue_from << RSpec::Expectations::ExpectationNotMetError

    retries = -1
    begin
      yield
    rescue Exception => e
      raise e if (retries += 1) >= retry_count || rescue_from.find {|r| e.is_a?(r) }.nil?
      sleep(retry_wait)
      retry
    end
  end

  def stub_master_setup_request_host
    ms = instance_double("MasterSetup")
    allow(ms).to receive(:request_host).and_return "localhost:3000"
    allow(ms).to receive(:system_code).and_return "test"
    allow(ms).to receive(:uuid).and_return "test-uuid"
    allow(ms).to receive(:custom_feature?).and_return false
    allow(ms).to receive(:production?).and_return false
    allow(MasterSetup).to receive(:get).and_return ms
    ms
  end

  def stub_master_setup
    stub_master_setup_request_host
  end

  def json_date date
    ActiveSupport::JSON.encode(date).gsub(/"/, "")
  end

  def expect_custom_value obj, cdef, value
    expect(obj.custom_value(cdef)).to eq value
  end

  class FakeSnapshotWriterImpl
    def self.entity_json entity
      "{\"fake\":#{entity.id}}"
    end
  end
end