require 'open_chain/s3'

# This class is the primary integration point between the OpenChain::IntegrationClient class (which is where all notifications
# of inbound files are processed) and the actual parser implementions that process those files.
# 
# In general, your parser should extend this module (thus making the methods class level) and then create a class level entry
# point method named parse that takes the raw file bytes as the first param (really a string) and then a hash that will have the 
# keys :bucket, and :key which define the S3 location of the file the data came from.
#
# You should also define a class method named integration_folder that returns the key path in the integration bucket that the
# files will be stored in (in general, you'll strip the date components at the front of the path and the actual filename to arrive 
# at this value).  Defining this method allows you to use the process_day and process_past_days methods for your parser.
#
module OpenChain; module IntegrationClientParser

  def process_past_days number_of_days, opts={:imaging=>false,:skip_delay=>false}
    # Make the processing order from oldest to newest to help avoid situations where old data overwrites newer data
    number_of_days.times.reverse_each do |i|
      if opts[:skip_delay]
        self.process_day i.days.ago, opts
      else
        self.delay(:priority=>500).process_day i.days.ago, opts
      end
    end
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

end; end
