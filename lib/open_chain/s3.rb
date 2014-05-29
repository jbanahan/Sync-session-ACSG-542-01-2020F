module OpenChain

  class S3
    BUCKETS = {:test => 'chain-io-test', :development=>'chain-io-dev', :production=>'chain-io'}

    def self.parse_full_s3_path path
      # We're expecting the path to be like "/bucket/path/to/file.pdf"
      # The first path segment of the file is the bucket, everything after that is the path to the actual file
      split_path = path.split("/")
      
      # If the path started with a / the first index is blank
      split_path.shift if split_path[0].strip.length == 0

      [split_path[0], split_path[1..-1].join("/")]
    end

    def self.upload_file bucket, key, file
      s3_action_with_retries do
        s3_obj = s3_file bucket, key
        s3_obj.write Pathname.new(file.path)
      end
    end

    # Retrieves the data specified by the bucket/key descriptor.
    # If the IO parameter is defined, the object is expected to be an IO-like object
    # (answering to write, flush and rewind) and all data is streamed directly to 
    # this object and nothing is returned.
    #
    # If no io object is provided, the full file content is returned.
    def self.get_data bucket, key, io = nil
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
        s3_file = s3_file(bucket, key)
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

    def self.s3_file bucket, key
      AWS::S3.new(AWS_CREDENTIALS).buckets[bucket].objects[key]
    end
    private_class_method :s3_file

    def self.s3_action_with_retries total_attempts = 3, retry_lambda = nil
      begin
        yield
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
      options = {:expires=>expires_in, :secure=>true}.merge options
      AWS::S3.new(AWS_CREDENTIALS).buckets[bucket].objects[key].url_for(:read, options).to_s
    end
    
    # Downloads the AWS S3 data specified by the bucket and key.  The tempfile
    # created will attempt to use the key as a template for naming the tempfile created.
    # Meaning, at a minimum, the file name name should retain the same file extension that
    # it currently has on the S3 file system.
    #
    # If a block is passed, the tempfile is yielded to the block as the sole argument and cleanup
    # of the tempfile is handled transparently to the caller.  The tempfile's will be set to read from the
    # beginning of the file when yielded.
    def self.download_to_tempfile bucket, key
      t = nil
      e = nil
      begin
        # Use the key's filename as the basis for the tempfile name
        t = create_tempfile key
        t.binmode
        OpenChain::S3.get_data bucket, key, t

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

    def self.delete bucket, key
      o = AWS::S3.new(AWS_CREDENTIALS).buckets[bucket].objects[key]
      o.delete if o.exists?
    end

    def self.bucket_name environment = Rails.env
      BUCKETS[environment.to_sym]      
    end

    def self.integration_bucket_name
      'chain-io-integration'
    end

    def self.exists? bucket, key
      AWS::S3.new(AWS_CREDENTIALS).buckets[bucket].objects[key].exists?
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
        AWS::S3.new(AWS_CREDENTIALS).buckets[integration_bucket_name].objects.with_prefix(prefix).sort_by {|o| o.last_modified}.each do |obj|
          yield obj.key
        end
      end
      
    end
  end
end
