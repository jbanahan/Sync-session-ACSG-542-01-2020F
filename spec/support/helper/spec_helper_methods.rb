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

  def create_edi_segments str, separator: "*", newline: "\n"
    segments = []
    str.split(newline).each_with_index do |seg_string, i|
      elements = []
      seg_string.split(separator).each_with_index { |elem_string, j| elements << REX12::Element.new(elem_string, j) }
      segments << REX12::Segment.new(elements, i)
    end
    segments
  end

  class MockS3
    class AwsErrors < StandardError; end
    class NoSuchKeyError < AwsErrors; end 

    class UploadResult

      attr_reader :bucket, :key, :version

      def initialize bucket, key, version
        @bucket = bucket
        @key = key
        @version = version
      end
    end

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

    def self.url_for bucket, key, expires_in=1.minute, options = {}
      "http://#{bucket}.s3.com/#{key}?expires_in=#{expires_in.to_i}"
    end
    
    def self.upload_data bucket_name, path, data, options = {}
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
      # Just transparently unzip the data if it's zipped before storing it.
      if options[:content_encoding] == "gzip"
        local_data = ActiveSupport::Gzip.decompress local_data
      end
      
      @datastore[key(bucket_name, path, @version_id)] = local_data

      UploadResult.new bucket_name, path, @version_id.to_s
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

    def self.exists? bucket, key, version = nil
      key != "bad_file"
    end

    def self.delete bucket, path, version = nil
      @datastore.delete key(bucket, path, version)
      true
    end

    # TODO - Reimplement the mocking of s3 to actually mock the underlying client and not
    # the outer OpenChain::S3 shell
    def self.download_to_tempfile bucket, key, options = {}
      raise "Method must be mocked!"
    end

    def self.each_file_in_bucket(bucket, max_files: nil, prefix: nil)
      raise "Method must be mocked!"
    end

    def self.metadata metadata_key, bucket, key, version = nil
      raise "Method must be mocked!"
    end

    def self.create_s3_tempfile local_file, bucket: 'test', tmp_s3_path: "test/temp"
      raise "Method must be mocked!"
    end

    def self.with_s3_tempfile local_file, bucket: 'test', tmp_s3_path: "test/temp"
      raise "Method must be mocked!"
    end

    def self.get_data bucket, key, io = nil
      raise "Method must be mocked!"
    end

    def self.bucket_exists? bucket_name
      raise "Method must be mocked!"
    end

    def self.copy_object from_bucket, from_key, to_bucket, to_key, from_version: nil
      raise "Method must be mocked!"
    end

    def self.create_bucket! bucket_name, opts={}
      raise "Method must be mocked!"
    end

    def self.integration_subfolder_path folder, upload_date
      raise "Method must be mocked!"
    end

    def self.bucket_exists? bucket_name
      raise "Method must be mocked!"
    end

    def self.integration_keys upload_date, subfolders
      raise "Method must be mocked!"
    end

    def self.zero_file bucket, key
      raise "Method must be mocked!"
    end

    def self.upload_file bucket, key, file, write_options = {}
      raise "Method must be mocked!"
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
    allow_any_instance_of(OpenMailer).to receive(:log_email).and_return SentEmail.new
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

  def stub_master_setup_for_reports
    ms = stub_master_setup
    allow(ms).to receive(:custom_feature?).with("WWW VFI Track Reports").and_return true
    ms
  end

  def json_date date
    ActiveSupport::JSON.encode(date).gsub(/"/, "")
  end

  def expect_custom_value obj, cdef, value
    expect(obj.custom_value(cdef)).to eq value
  end

  def snapshot_json obj
    ActiveSupport::JSON.decode(CoreModule.find_by_object(obj).entity_json obj)
  end

  class FakeSnapshotWriterImpl
    def self.entity_json entity
      "{\"fake\":#{entity.id}}"
    end
  end

  # This class is NOT meant to be used in production, it's a simple class that can be used to read some data from an xlsx stream/file path
  # for test verification
  class XlsxTestReader
    attr_reader :workbook

    def initialize io
      if io.is_a?(String)
        @workbook = RubyXL::Parser.parse(io)
      elsif io.is_a?(XlsxBuilder)
        stringio = StringIO.new
        io.write stringio
        stringio.rewind
        @workbook = RubyXL::Parser.parse_buffer(stringio)
      else
        @workbook = RubyXL::Parser.parse_buffer(io)
      end
    end

    def cell sheet, row_index, column_index
      sheet(sheet) do |ws|
        return ws[row_index][column_index]
      end
    end

    def row sheet, row_index
      sheet(sheet) do |ws|
        return ws[row_index]
      end
    end

    def sheet xlsx_sheet
      if xlsx_sheet.is_a?(RubyXL::Worksheet)
        sheet = xlsx_sheet
      elsif xlsx_sheet.respond_to?(:name)
        # This allows us to actually use straight XlsxBuilder::XlsxSheet objecds too
        sheet = @workbook[xlsx_sheet.name]
      else
        sheet = @workbook[xlsx_sheet]
      end

      if block_given?
        yield sheet
      else 
        return sheet
      end
      nil
    end

    def background_color sheet, row, column
      cell = self.cell sheet, row, column
      cell.try(:fill_color)
    end

    def number_format sheet, row, column
      cell = self.cell(sheet, row, column)
      return nil unless cell
      xf = cell.send(:get_cell_xf)
      return nil unless xf

      format = self.workbook.stylesheet.number_formats.find_by_format_id xf.num_fmt_id
      format.try(:format_code)
    end

    def merged_cell_ranges sheet
      self.sheet(sheet) do |ws|
        return ws.merged_cells.map{ |mc| {row: mc.ref.row_range.first, cols: mc.ref.col_range } }
      end
    end

    def width_at sheet, column
      self.sheet(sheet) do |ws|
        return ws.get_column_width_raw column
      end
    end

    def raw_data sheet
      self.sheet(sheet) do |worksheet|
        data = []
        worksheet.each do |row|
          vals = []
          row.cells.each do |cell|
            v = cell.try(:value)
            if v.is_a?(DateTime)
              # DateTimes suck - Also note that since the DateTime has no timzone (nor does Excel carry any
              # semblance of one), the TimeWithZone you get back is going to reflect the raw time in the 
              # default timezone (not necessarily the offset you might expect)
              v = Time.zone.parse(v.iso8601)
            end

            vals << v
          end
          data << vals
        end

        return data
      end
    end

    def raw_workbook_data
      data = {}
      @workbook.each do |sheet|
        data[sheet.sheet_name] = raw_data(sheet)
      end

      data
    end
  end

  def populate_custom_values object, custom_definitions
    # Most specs that utilize cdefs reference the custom definitions of the class under test,
    # that method returns a hash of identifiers to the custom definitions, that's what we're 
    # possible expecting and handling here.
    if custom_definitions.is_a?(Hash)
      custom_definitions = custom_definitions.values
    end

    obj_class = object.class.to_s
    custom_definitions.each do |cd|
      next unless cd.core_module.class_name == obj_class

      value = case cd.data_type.to_s
      when "string", "text"
        cd.cdef_uid.to_s
      when "date"
        cd.created_at.to_date
      when "datetime"
        cd.created_at
      when "decimal", "integer"
        cd.id
      when "boolean"
        true
      else
        raise "Unexpected CustomDefinition data type #{cd.data_type.to_s}"
      end
      object.update_custom_value! cd, value
    end
    nil
  end

  def xlsx_data spreadsheet_data, sheet_name: nil
    data = spreadsheet_data
    # we're going to assume anything other than an xlsx builder is an IO
    if spreadsheet_data.is_a?(XlsxBuilder)
      data = StringIO.new
      spreadsheet_data.write data
      data.rewind
    end
    d = XlsxTestReader.new data
    raw_data = d.raw_workbook_data
    sheet_name.blank? ? raw_data : raw_data[sheet_name]
  end
  
  def add_system_identifier(company, system, code)
    company.system_identifiers.create! system: system, code: code
    company
  end

  def with_customs_management_id(company, code)
    add_system_identifier(company, "Customs Management", code)
  end

  def with_fenix_id(company, code)
    add_system_identifier(company, "Fenix", code)
  end

  def with_cargowise_id(company, code)
    add_system_identifier(company, "Cargowise", code)
  end

end
