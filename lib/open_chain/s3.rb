module OpenChain

  class S3
    BUCKETS = {:test => 'chain-io-test', :development=>'chain-io-dev', :production=>'chain-io'}

    def self.upload_file bucket, key, file
      AWS::S3.new(AWS_CREDENTIALS).buckets[bucket].objects[key].write(:file=>file.path)
    end
    def self.download_to_tempfile bucket, key
      t = Tempfile.new('iodownload')
      t.write AWS::S3.new(AWS_CREDENTIALS).buckets[bucket].objects[key].read
      t.flush
      t
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
  end
end
