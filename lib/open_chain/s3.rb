module OpenChain

  class S3
    BUCKETS = {:test => 'chain-io-test', :development=>'chain-io-dev', :production=>'chain-io'}

    def self.upload_file bucket, key, file
      AWS::S3.new(AWS_CREDENTIALS).buckets[bucket].objects[key].write(:file=>file.path)
    end
    def self.get_data bucket, key
      AWS::S3.new(AWS_CREDENTIALS).buckets[bucket].objects[key].read
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
        t.write OpenChain::S3.get_data bucket, key
        t.flush

        # Reset the read/write pointer to the beginning of the file so we can actually read from the file
        # as an IO object. 
        t.rewind

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
    def self.integration_keys upload_date, subfolder
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
