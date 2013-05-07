module OpenChain
  #adds static methods for processing data from S3, expects class to implement static integration_folder method to return location in s3 for files
  module IntegrationClientParser
    def process_past_days number_of_days, opts={:imaging=>false}
      # Make the processing order from oldest to newest to help avoid situations where old data overwrites newer data
      number_of_days.times.reverse_each {|i| self.delay(:priority=>500).process_day i.days.ago, opts}
    end
    # process all files in the archive for a given date.  Use this to reprocess old files. By default it skips the call to the imaging server
    def process_day date, opts={:imaging=>false}
      OpenChain::S3.integration_keys(date,self.integration_folder) do |key|
        process_from_s3 OpenChain::S3.integration_bucket_name, key, opts
      end
    end

    def process_from_s3 bucket, key, opts={}
      parse OpenChain::S3.get_data(bucket, key), {:bucket=>bucket, :key=>key}.merge(opts)
    end
  end
end
