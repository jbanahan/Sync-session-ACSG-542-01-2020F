require 'aws-sdk'
require 'open_chain/aws_config_support'

module OpenChain; class S3

  BUCKETS ||= {:test => 'chain-io-test', :development=>'chain-io-dev', :production=>'chain-io'}

  def self.parse_full_s3_path path
    # We're expecting the path to be like "/bucket/path/to/file.pdf"
    # The first path segment of the file is the bucket, everything after that is the path to the actual file key
    bucket, *key = Pathname.new(path).each_filename.to_a
    [bucket, key.join("/")]
  end

  # returns S3Object, ObjectVersion
  def self.upload_file bucket, key, file, write_options = {}
    data = Pathname.new(file.to_path)
    # Open a separate instance of the file in this case...this is mostly just in keeping backwards compatibility
    # since this is how the system used to do this.  If you really want to upload a file directly without tampering, use upload_data
    File.open(data.to_s, "rb") do |f|
      return Client.s3_upload_io bucket, key, f, write_options
    end
  end

  # Create or replace the data at a given key with a blank file
  def self.zero_file bucket, key
    upload_data(bucket, key, nil)
  end

  # Use when you want to upload the data given in the data param as the body of the file (.ie data is NOT a path to a file)
  def self.upload_data bucket, key, data, write_options = {}
    if !data.is_a?(IO)
      data = StringIO.new data.to_s
    end

    return Client.s3_upload_io bucket, key, data, write_options
  end

  # Uploads the given local_file to a temp location in S3 
  def self.with_s3_tempfile local_file, bucket: 'chainio-temp', tmp_s3_path: "#{MasterSetup.get.uuid}/temp"
    upload_response = nil
    begin
      upload_response = create_s3_tempfile(local_file, bucket: bucket, tmp_s3_path: tmp_s3_path)
      yield upload_response
    ensure
      delete(upload_response.bucket, upload_response.key, upload_response.version) if upload_response
    end
    nil
  end

  def self.create_s3_tempfile local_file, bucket: 'chainio-temp', tmp_s3_path: "#{MasterSetup.get.uuid}/temp"
    filename = local_file.respond_to?(:original_filename) ? local_file.original_filename : local_file.path
    key = tmp_s3_path + "/" + File.basename(filename)
    upload_file(bucket, key, local_file)
  end

  # Find out if a bucket exists in the S3 environment
  def self.bucket_exists? bucket_name
    Client.bucket_exists? bucket_name
  end

  # Create a new bucket
  #
  # if :versioning option evaluates to true, then versioning will be turned on before the object is returned
  def self.create_bucket! bucket_name, opts={}
    Client.create_bucket! bucket_name, opts
    true
  end

  # Same functionality as get_data but with specified object version
  def self.get_versioned_data bucket, key, version, io = nil
    Client.get_versioned_data bucket, key, version: version, io: io
  end

  # Retrieves the data specified by the bucket/key descriptor.
  # If the IO parameter is defined, the object is expected to be an IO-like object
  # (answering to write, flush and rewind) and all data is streamed directly to 
  # this object and nothing is returned.
  #
  # If no io object is provided, the full file content is returned.
  def self.get_data bucket, key, io = nil
    Client.get_versioned_data bucket, key, io: io
  end

  def self.url_for bucket, key, expires_in=1.minute, options = {}
    version = options.delete :version
    options = {:expires_in=>expires_in.to_i, :secure=>true}.merge options
    options[:version_id] = version unless version.blank?
    # Purposefully not using the version here...the version to use gets passed to the presigner as an option
    obj = Client.s3_versioned_object(bucket, key)
    obj.try(:presigned_url, :get, options).to_s
  end

  def self.metadata metadata_key, bucket, key, version = nil
    if version.nil?
      Client.s3_file(bucket, key).metadata[metadata_key]
    else
      # Versioned Objects don't support direct metadata retrieval
      Client.s3_versioned_object(bucket, key, version).head.metadata[metadata_key]
    end
  end

  def self.each_file_in_bucket(bucket, max_files: nil, prefix: nil)
    objects = Client.list_objects(bucket, max_files: max_files, prefix: prefix)
    objects.each {|o| yield o[:key], o[:version] }
    nil
  end
  
  # Downloads the AWS S3 data specified by the bucket and key (and optional version).  The tempfile
  # created will attempt to use the key as a template for naming the tempfile created.
  # Meaning, at a minimum, the file name name should retain the same file extension that
  # it currently has on the S3 file system.  If you wish to get the actual filename,
  # utilize the original_filename option and a original_filename method will get added to the 
  # tempfile.
  # 
  # To retrieve versioned data, pass the file version with the version option
  #
  # If a block is passed, the tempfile is yielded to the block as the sole argument and cleanup
  # of the tempfile is handled transparently to the caller. The tempfile's will be set to read from the
  # beginning of the file when yielded.
  def self.download_to_tempfile bucket, key, options = {}
    t = nil
    e = nil
    begin
      # Use the key's filename as the basis for the tempfile name
      t = create_tempfile key
      t.binmode
      Client.get_versioned_data bucket, key, version: options[:version], io: t

      unless options[:original_filename].to_s.blank?
        Attachment.add_original_filename_method t, options[:original_filename].to_s
      end

      # pass the tempfile to any given block
      if block_given?
        yield t
      else
        return t
      end
    rescue Exception
      # We don't particularly care about the error here...just want to give an indicator
      # to our ensure clause to tell it there was an error and to clean up the tempfile.
      e = true
      raise $!
    ensure 
      # We want to make sure we destroy the tempfile if we yield to a block or
      # if something was raised inside the above block
      t.close! if t && (e || block_given?)
    end
  end

  # Method exists purely for test purposes
  def self.create_tempfile key
    Tempfile.new([File.basename(key, ".*"), File.extname(key)])
  end
  private_class_method :create_tempfile

  def self.delete bucket, key, version = nil
    # There is no indicator from the s3 lib when a file doesn't exist and delete is called on it, so 
    # there's not much of a point in differentiating a true/false return value here...always return true.
    # NOTE: If the bucket doesn't exist a Aws::S3::Errors::NoSuchBucket error is raised.  We'll allow this
    # to raise, since if that's happening, then it's likely you've got some bad code that needs to get taken care of.
    Client.delete bucket, key, version
    true
  end

  def self.bucket_name environment = Rails.env
    BUCKETS[environment.to_sym]      
  end

  def self.integration_bucket_name
    'chain-io-integration'
  end

  def self.exists? bucket, key, version = nil
    Client.exists? bucket, key, version
  end

  # get files uploaded to the integration bucket for a particular date and subfolder and passes each key name to the given block
  def self.integration_keys upload_date, subfolders
    # For the time being, we need to support looking for files in multiple locations after migrating the integration code
    # to a new machine.  The integration_client_parser implementations will all return multiple integration folders to check
    # for files to process.  This ammounts primarily just to a single extra HTTP call per subfolder listed.
    Array.wrap(subfolders).each do |subfolder|
      prefix = integration_subfolder_path(subfolder, upload_date)
      
      # The sort call here is to make sure we're processing all the files nearest to the order they were received
      # in using the last modified date.  This is the only "standard" metadata date we get on all objects, so technically
      # it's not going to be 100% reliable if we update a file ever, but I'm not sure if that'll ever really happen anyway
      # so it should be close enough to 100% reliable for us.

      # Also note, this call does make HTTP HEAD requests for every S3 object being sorted.  It's somewhat expensive
      # to do this but works in all storage cases and doesn't have to rely on storage naming standards.
      Client.s3_bucket(integration_bucket_name).objects(prefix: prefix).sort_by {|o| o.last_modified }.each do |obj|
        yield obj.key
      end
    end
  end

  def self.integration_subfolder_path folder, upload_date
    # Strip any leading slash from the subfolder since we add one below...this allows us to use the actual
    # absolute path to the integration directory in the parsers, vs. what looks like a relative path.  
    folder = folder[1..-1] if folder.start_with? "/"
    "#{upload_date.strftime("%Y-%m/%d")}/#{folder}"
  end

  class UploadResult

    attr_reader :bucket, :key, :version

    def initialize bucket, key, version
      @bucket = bucket
      @key = key
      @version = version
    end

    def self.from_put_object_response bucket, key, resp
      self.new bucket, key, resp.version_id
    end
  end

  class AwsErrors < StandardError; end

  class NoSuchKeyError < AwsErrors
    attr_reader :bucket, :key, :version

    def initialize bucket, key, version, message
      message = "#{message} (Bucket: #{bucket} / Key: #{key} / Version: #{version})"
      super(message)
      @bucket = bucket
      @key = key
      @version = version
    end

  end

  # Any direct interactions with aws lib should occur inside this class, any code outside of OpenChain::S3 should NOT
  # directly interact with this code.
  class Client
    extend OpenChain::AwsConfigSupport

    # returns S3Object, ObjectVersion
    def self.s3_upload_io bucket, key, data, write_options = {}
      # Everything passed into this method SHOULD respond to rewind
      retry_lambda = lambda { data.rewind } 
      s3_action_with_retries(retry_lambda: retry_lambda) do
        # This initiates an upload in a single request...this functionally limits the size of the upload to < 5GB...which is fine for
        # our current use cases.
        response = s3_client.put_object write_options.merge(bucket: bucket, key: key, body: data)
        return UploadResult.from_put_object_response(bucket, key, response)
      end
    end

    # Find out if a bucket exists in the S3 environment
    def self.bucket_exists? bucket_name
      s3_bucket(bucket_name).exists?
    end

    # Create a new bucket
    #
    # if :versioning option evaluates to true, then versioning will be turned on before the object is returned
    def self.create_bucket! bucket_name, opts={}
      s3_client.create_bucket(bucket: bucket_name)
      b = s3_bucket(bucket_name)

      if opts[:versioning]
        b.versioning.enable
      end
      
      true
    end

    def self.get_versioned_data bucket, key, version: nil, io: nil
      retry_lambda = lambda {
        if io
          # If we started writing to a file, we need to truncate what we've already written
          # and start from scratch when we've failed
          if io.respond_to? :truncate
            io.truncate(0)
          else
            io.rewind
          end
        end
      }
      opts = {bucket: bucket, key: key}
      opts[:version_id] = version unless version.blank?

      s3_action_with_retries(retry_lambda: retry_lambda) do
        if io
          s3_client.get_object(opts) {|chunk| io.write chunk }

          # Flush the data and reset the read/write pointer to the beginning of the IO object 
          # so the caller can then actually read from the file.
          io.flush
          io.rewind
          nil
        else
          response = s3_client.get_object opts
          response.body.read
        end
      end
    rescue Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::NoSuchVersion => e
      err = NoSuchKeyError.new(bucket, key, version, e.message)
      err.set_backtrace(e.backtrace)
      raise err
    end

    # You can use this method to front any handling of s3 data that is used for versioning where both 
    # S3:S3Object and S3::ObjectVersion share methods (like #key, #metadata, #read, #delete, #bucket, #url_for)
    def self.s3_versioned_object bucket, key, version = nil
      s3_obj = s3_file(bucket, key)
      if !version.blank?
        s3_obj = s3_obj.version(version)
      end
      s3_obj
    end

    def self.exists? bucket, key, version = nil
      # S3::ObjectVersion doesn't seem to have a way to actually check if the version itself is present...
      # We can imitate the method by doing a head call on ObjectVersion, which will raise an error if it doesn't exist
      val = nil
      if version
        vo = s3_versioned_object(bucket, key, version)
        head = vo.head rescue nil
        val = !head.nil? 
      else
        val = s3_file(bucket, key).exists?
      end
      val
    end

    def self.delete bucket, key, version = nil
      obj = s3_versioned_object(bucket, key, version)
      obj.delete
    end

    def self.list_objects bucket, prefix: nil, max_files: nil
      # Just set some arbitrarily high value here if max_objects isn't sent
      max_files = 100000 if max_files.nil?

      objects = []
      continue_listing = true
      version_id_marker = nil
      key_marker = nil

      begin
        max_keys = [(max_files - objects.length), 1000].min
        resp = s3_client.list_object_versions(bucket: bucket, max_keys: max_keys, prefix: prefix, key_marker: key_marker, version_id_marker: version_id_marker)
        key_marker = resp.next_key_marker
        version_id_marker = resp.next_version_id_marker
        resp.versions.each do |v|
          objects << {last_modified: v.last_modified, key: v.key, version: v.version_id}
          break if objects.length == max_files
        end
        continue_listing = objects.length < max_files && resp.is_truncated
      end while continue_listing
      
      # Now sort all the objects by last_modified_date
      objects.sort_by {|k| k[:last_modified] }
    end

    def self.s3_action_with_retries total_attempts: 3, retry_lambda: nil
      begin
        return yield
      rescue 
        total_attempts -= 1
        if total_attempts > 0
          sleep 0.25
          retry_lambda.call if retry_lambda
          retry
        else
          raise
        end
      end
    end
    private_class_method :s3_action_with_retries

    def self.s3_bucket bucket
      aws_s3.bucket(bucket)
    end

    def self.s3_file bucket, key
      s3_bucket(bucket).try(:object, key)
    end

    def self.aws_s3
      ::Aws::S3::Resource.new client: s3_client
    end
    private_class_method :aws_s3

    def self.s3_client
      ::Aws::S3::Client.new(aws_config)
    end
    private_class_method :s3_client

  end

end; end
