module OpenChain

  class S3
    BUCKETS = {:test => 'chain-io-test', :development=>'chain-io-dev', :production=>'chain-io'}

    def self.parse_full_s3_path path
      # We're expecting the path to be like "/bucket/path/to/file.pdf"
      # The first path segment of the file is the bucket, everything after that is the path to the actual file key
      bucket, *key = Pathname.new(path).each_filename.to_a
      [bucket, key.join("/")]
    end

    # returns S3Object, ObjectVersion
    def self.upload_data bucket, key, data, write_options = {}
      s3_action_with_retries do
        s3_obj = s3_file bucket, key
        out = s3_obj.write data, write_options
        if out.respond_to?(:object)
          return [out.object, out]
        else
          return [out, nil]
        end
      end
    end

    # returns S3Object, ObjectVersion
    def self.upload_file bucket, key, file, write_options = {}
      data = Pathname.new(file.to_path)
      return upload_data bucket, key, data, write_options
    end

    # Uploads the given local_file to a temp location in S3 
    def self.with_s3_tempfile local_file, bucket: 'chainio-temp', tmp_s3_path: "#{MasterSetup.get.uuid}/temp"
      s3_object = nil
      begin
        s3_object = create_s3_tempfile(local_file, bucket: bucket, tmp_s3_path: tmp_s3_path)
        yield s3_object
      ensure
        delete(s3_object.bucket.name, s3_object.key) if s3_object && s3_object.exists?
      end
      nil
    end

    def self.create_s3_tempfile local_file, bucket: 'chainio-temp', tmp_s3_path: "#{MasterSetup.get.uuid}/temp"
      filename = local_file.respond_to?(:original_filename) ? local_file.original_filename : local_file.path
      key = tmp_s3_path + "/" + File.basename(filename)
      obj = upload_file(bucket, key, local_file)
      obj ? obj.first : nil
    end

    # Find out if a bucket exists in the S3 environment
    def self.bucket_exists? bucket_name
      aws_s3.buckets[bucket_name].exists?
    end

    # Create a new bucket
    #
    # if :versioning option evaluates to true, then versioning will be turned on before the object is returned
    def self.create_bucket! bucket_name, opts={}
      b = aws_s3.buckets.create(bucket_name)
      b.enable_versioning if opts[:versioning]
      return b
    end

    def self.aws_s3
      AWS::S3.new(AWS_CREDENTIALS)
    end
    private_class_method :aws_s3

    # Same functionality as get_data but with specified object version
    def self.get_versioned_data bucket, key, version, io = nil
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
      s3_action_with_retries 3, retry_lambda do
        s3_file = s3_versioned_object(bucket, key, version)
        if io
          s3_file.read {|chunk| io.write chunk}
          # Flush the data and reset the read/write pointer to the beginning of the IO object 
          # so the caller can then actually read from the file.
          io.flush
          io.rewind
          nil
        else
          s3_file.read
        end
      end
    end
    # Retrieves the data specified by the bucket/key descriptor.
    # If the IO parameter is defined, the object is expected to be an IO-like object
    # (answering to write, flush and rewind) and all data is streamed directly to 
    # this object and nothing is returned.
    #
    # If no io object is provided, the full file content is returned.
    def self.get_data bucket, key, io = nil
      get_versioned_data(bucket,key,nil,io)
    end

    def self.s3_file bucket, key
      aws_s3.buckets[bucket].objects[key]
    end
    private_class_method :s3_file

    # You can use this method to front any handling of s3 data that is used for versioning where both 
    # S3:S3Object and S3::ObjectVersion share methods (like #key, #metadata, #read, #delete, #bucket, #url_for)
    def self.s3_versioned_object bucket, key, version = nil
      s3_obj = s3_file(bucket, key)
      if !version.blank?
        s3_obj = s3_obj.versions[version]
      end
      s3_obj
    end
    private_class_method :s3_versioned_object

    def self.s3_action_with_retries total_attempts = 3, retry_lambda = nil
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

    def self.url_for bucket, key, expires_in=1.minute, options = {}
      version = options.delete :version
      options = {:expires=>expires_in, :secure=>true}.merge options
      s3_versioned_object(bucket, key, version).url_for(:read, options).to_s
    end

    def self.metadata metadata_key, bucket, key, version = nil
      s3_versioned_object(bucket, key, version).metadata[metadata_key]
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
    # of the tempfile is handled transparently to the caller.  The tempfile's will be set to read from the
    # beginning of the file when yielded.
    def self.download_to_tempfile bucket, key, options = {}
      t = nil
      e = nil
      begin
        # Use the key's filename as the basis for the tempfile name
        t = create_tempfile key
        t.binmode
        get_versioned_data bucket, key, options[:version], t

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

    def self.create_tempfile key
      Tempfile.new([File.basename(key, ".*"), File.extname(key)])
    end

    def self.delete bucket, key, version = nil
      obj = s3_versioned_object(bucket, key, version)
      obj.delete
    end

    def self.bucket_name environment = Rails.env
      BUCKETS[environment.to_sym]      
    end

    def self.integration_bucket_name
      'chain-io-integration'
    end

    def self.exists? bucket, key
      aws_s3.buckets[bucket].objects[key].exists?
    end

    # get files uploaded to the integration bucket for a particular date and subfolder and passes each key name to the given block
    def self.integration_keys upload_date, subfolders
      # For the time being, we need to support looking for files in multiple locations after migrating the integration code
      # to a new machine.  The integration_client_parser implementations will all return multiple integration folders to check
      # for files to process.  This ammounts primarily just to a single extra HTTP call per subfolder listed.
      subfolders = subfolders.respond_to?(:to_a) ? subfolders.to_a : [subfolders]

      subfolders.each do |subfolder|
        # Strip any leading slash from the subfolder since we add one below...this allows us to use the actual
        # absolute path to the integration directory in the parsers, vs. what looks like a relative path.
        subfolder = subfolder[1..-1] if subfolder.start_with? "/"
        prefix = "#{upload_date.strftime("%Y-%m/%d")}/#{subfolder}"
        
        # The sort call here is to make sure we're processing all the files nearest to the order they were received
        # in using the last modified date.  This is the only "standard" metadata date we get on all objects, so technically
        # it's not going to be 100% reliable if we update a file ever, but I'm not sure if that'll ever really happen anyway
        # so it should be close enough to 100% reliable for us.

        # Also note, this call does make HTTP HEAD requests for every S3 object being sorted.  It's somewhat expensive
        # to do this but works in all storage cases and doesn't have to rely on storage naming standards.
        aws_s3.buckets[integration_bucket_name].objects.with_prefix(prefix).sort_by {|o| o.last_modified}.each do |obj|
          yield obj.key
        end
      end
      
    end
  end
end
