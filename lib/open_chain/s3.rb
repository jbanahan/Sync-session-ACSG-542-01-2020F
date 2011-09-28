module OpenChain

  class S3
    BUCKETS = {:test => 'chain-io-test', :development=>'chain-io-dev', :production=>'chain-io'}

    def self.upload_file bucket, key, file
      connect
      AWS::S3::S3Object.store(key, open(file), bucket)
    end
    def self.download_to_tempfile bucket, key
      t = Tempfile.new('iodownload')
      begin
        AWS::S3::S3Object.stream(key, bucket) do |chunk|
          t.write chunk
        end
      ensure
        t.close
      end
      t
    end

    def self.delete bucket, key
      AWS::S3::S3Object.delete key, bucket
    end

    def self.bucket_name environment = Rails.env
      BUCKETS[environment.to_sym]      
    end

    def self.exists? bucket, key
      connect
      AWS::S3::S3Object.exists? key, bucket
    end

    private
    #connect if not already connected
    def self.connect
      base = YAML.load(IO.read("config/s3.yml"))
      y = {} #need to convert string keys into symbols
      base.each do |k,v|
        y[k.to_sym] = v
      end
      AWS::S3::Base.establish_connection!(y) unless AWS::S3::Base.connected?
    end
  end
end
