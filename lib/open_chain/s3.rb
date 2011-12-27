module OpenChain

  class S3
    BUCKETS = {:test => 'chain-io-test', :development=>'chain-io-dev', :production=>'chain-io'}

    def self.upload_file bucket, key, file
      AWS::S3.new(AWS_CREDENTIALS).buckets[bucket].objects[key].write(:file=>file.path)
    end
    def self.get_data bucket, key
      AWS::S3.new(AWS_CREDENTIALS).buckets[bucket].objects[key].read
    end
    def self.download_to_tempfile bucket, key
      t = Tempfile.new('iodownload')
      t.binmode
      t.write OpenChain::S3.get_data bucket, key
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

    # get files uploaded to the integration bucket for a particular date and subfolder and passes each key name to the given block
    def self.integration_keys upload_date, subfolder
      prefix = "#{upload_date.strftime("%Y-%m/%d")}/#{subfolder}"
      AWS::S3.new(AWS_CREDENTIALS).buckets[integration_bucket_name].objects.with_prefix(prefix).each do |obj|
        yield obj.key
      end
    end
  end
end
