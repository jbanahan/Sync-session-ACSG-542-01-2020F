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
    log = setup_inbound_file_log bucket, key
    begin
      data = OpenChain::S3.get_data(bucket, key)
      opts = {:bucket=>bucket, :key=>key}.merge(opts)
      if self.respond_to?(:parse_file)
        parse_file data, log, opts
      else
        parse data, opts.merge(log: log)
      end
    rescue Exception => e
      # Log the exception unless we've already logged it, which will be the case if one of these LoggedParser error
      # classes are involved.
      if !e.is_a?(LoggedParserRejectionError) && !e.is_a?(LoggedParserFatalError)
        log.add_error_message e.to_s
      end

      # Re-raise the error unless we're dealing with an UnreportedError.  (LoggedParserRejectionError extends
      # UnreportedError.) If that's the case, it's safe to just eat it.
      if !e.is_a?(UnreportedError)
        raise
      end
    ensure
      finalize_inbound_file_log log, opts
    end
  end

  # When the code that runs on the FTP server picks up files, it inserts a timestamp into the filename, ostensibly
  # so we don't get two files named the same thing put into the archive in the same day.  This method returns the
  # "original" filename without the timestamp.
  def get_s3_key_without_timestamp s3_key
    split_name = s3_key.nil? ? [] : s3_key.split(".")
    return s3_key unless split_name.length > 2
    (split_name[0..-3] + split_name[-1..-1]).join "."
  end

  # Parsers that should not be logging inbound file records can override this method.  S3 bucket and key can be used
  # for finer-grained filtration than parser-level may allow.
  def log_file? bucket, key
    true
  end

  private
    # Populates nearly everything in a new inbound file record, with the exception of...
    #   1. Company ID
    #   2. ISA Number
    #   3. Messages
    #   4. Identifiers (which include hooks to the modules being updated)
    # This content needs to be set within the actual parser classes.
    # Process End Date and Process Status are automatically populated later.  (Process Status gets a temp "Pending"
    # value here.)
    def setup_inbound_file_log bucket, key
      log = InboundFile.new
      log.process_start_date = Time.zone.now
      log.original_process_start_date = log.process_start_date
      log.s3_bucket = bucket
      log.s3_path = key
      log.process_status = InboundFile::PROCESS_STATUS_PENDING
      log.parser_name = parser_class_name

      abbrev_key = get_s3_key_without_timestamp key
      log.file_name = File.basename(abbrev_key)
      log.receipt_location = File.dirname(abbrev_key)
      log.requeue_count = 0

      # Look for an existing log.  This can happen, in certain cases, for documents being auto-reprocessed due to
      # issues like database burps and so forth.  Should we find a match on the S3 bucket and path, that record can
      # be destroyed and replaced, taking care to capture a couple fields meant to persist through reprocessings first.
      existing_log = InboundFile.where(s3_bucket:bucket, s3_path:key).first
      if existing_log
        log.requeue_count = existing_log.requeue_count + 1
        log.original_process_start_date = existing_log.original_process_start_date
        existing_log.destroy
      end

      log
    end

    # Handle cases where this module is both included and extended.
    def parser_class_name
      if self.is_a? Class
        self.to_s
      else
        self.class.to_s
      end
    end

    def finalize_inbound_file_log log, opts
      log.remove_dupe_messages
      log.process_status = log.get_process_status_from_messages
      log.process_end_date = Time.zone.now
      # 'force_inbound_file_logging' option allows for short-term logging of inbound file records for parsers that
      # may have the function disabled normally.
      log.save! if (log_file?(log.s3_bucket, log.s3_path) || opts[:force_inbound_file_logging])
    end

end; end
