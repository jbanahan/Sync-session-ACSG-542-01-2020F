require 'open_chain/s3'

# This class is the primary integration point between the OpenChain::IntegrationClient class (which is where all notifications
# of inbound files are processed) and the actual parser implementions that process those files.
#
# In general, your parser should extend this module (thus making the methods class level) and then create a class level entry
# point method named parse that takes the raw file bytes as the first param (really a string) and then a hash that will have the
# keys :bucket, and :key which define the S3 location of the file the data came from.
#

module OpenChain; module IntegrationClientParser
  extend ActiveSupport::Concern

  # This method will provide the implementing parser with the current InboundFile log object that was created
  # for this particular file run.  This is a convenient way to avoid having to pass the log through every single
  # method.
  def inbound_file
    self.class.inbound_file
  end

  module ClassMethods

    # This is the PRIMARY external means of processing a file.  The IntegrationClient will
    # execute it for any file received.
    def process_from_s3 bucket, key, opts={}
      handle_processing(bucket, key, opts) do
        retrieve_file_data(bucket, key, opts)
      end
    end

    def retrieve_file_data bucket, key, opts
      OpenChain::S3.get_data(bucket, key)
    end

    # Process, from the integration bucket, all the files that were received going
    # back X number of days.
    def process_past_days number_of_days, opts={:imaging=>false, :skip_delay=>false}
      # Make the processing order from oldest to newest to help avoid situations where old data overwrites newer data
      number_of_days.times.reverse_each do |i|
        if opts[:skip_delay]
          self.process_day i.days.ago, opts
        else
          self.delay(:priority=>500).process_day i.days.ago, opts
        end
      end
    end

    # Process all files in the archive for a given date.  Use this to reprocess old files. By default it skips the call to the imaging server
    def process_day date, opts={:imaging=>false}
      OpenChain::S3.integration_keys(date, self.integration_folder) do |key|
        process_from_s3 OpenChain::S3.integration_bucket_name, key, opts
      end
    end

    def delay_file_chunk_to_s3 filename, chunk_io, original_parse_opts, delete_from_s3: true, parse_method: :parse_file_chunk
      # if the original_opts references the log object, we need to remove it...otherwise the object won't deserialize
      # Plus, we don't want to try and use the same log object for all the chunks of the file.
      if original_parse_opts && original_parse_opts[:log].is_a?(InboundFile)
        original_parse_opts = original_parse_opts.deep_dup
        original_parse_opts.delete :log
      end

      full_path = "#{MasterSetup.get.system_code}/#{parser_class_name}/#{Time.zone.now.to_f}-#{File.basename(filename)}"
      result = OpenChain::S3.upload_data "chain-io-integration-temp", full_path, chunk_io
      self.delay.process_file_chunk_from_s3(result.bucket, result.key, original_parse_opts, delete_from_s3: delete_from_s3, parse_method: parse_method)
      nil
    end

    def process_file_chunk_from_s3 bucket, key, original_opts, delete_from_s3: true, parse_method: :parse_file_chunk
      data = retrieve_file_data(bucket, key, original_opts)
      self.public_send(parse_method, data, original_opts)
      OpenChain::S3.delete(bucket, key) if delete_from_s3
      nil
    end

    # This method is not really meant to be run in production, it's meant as a development helper.
    # Pass a path or a File object.
    def process_from_file file, opts={}
      if file.is_a?(String) || file.is_a?(Pathname)
        file = File.open(file.to_s, "rb")
      end

      handle_processing(nil, file.path, opts) do
        file.read
      end
    end

    # Handles all the acutal processing of the file data return by the given block
    def handle_processing bucket, key, opts = {}
      log = setup_inbound_file_log bucket, key
      set_inbound_file log
      data = nil
      begin
        data = yield

        # Check for an empty file.  Unless we've specifically allowed this parser to deal with them, this is the
        # point where we quit processing.
        if file_empty?(data) && !process_zero_byte_files?
          log.add_info_message "Zero byte file was not processed."
          return
        end

        if self.respond_to?(:pre_process_data)
          # This method can be used to do things like set a non-standard encoding.  Having this method makes it easier for
          # parsers that utilize frameworks that already implement the parse data to deal with having to mutute the incoming data
          # prior to the framework's parse method executing (.ie edi_parser_support).
          proced_data = pre_process_data(data, opts)
          # If we just mutated the data in place and nil is returned, then don't modify our data var, continue to use it as is.
          # If anything other than nil is returned, then use that instead of the existing data.
          data = proced_data unless proced_data.nil?
        end

        opts = {:bucket=>bucket, :key=>key}.merge(opts)
        if self.respond_to?(:parse_file)
          parse_file data, log, opts
        else
          parse data, opts.merge({log: log})
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
        begin
          finalize_inbound_file_log log, opts
        ensure
          begin
            if !file_empty?(data) || process_zero_byte_files?
              post_process_data data
            end
          ensure
            set_inbound_file nil
          end
        end
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

    # This method will provide the implementing parser with the current InboundFile log object that was created
    # for this particular file run.  This is a convenient way to avoid having to pass the log through every single
    # method.
    def inbound_file
      Thread.current.thread_variable_get("inbound_file")
    end

    def set_inbound_file log
      Thread.current.thread_variable_set("inbound_file", log)
    end

    def post_process_data data
      # Do nothing by default, this is here for parser to implement if they need to do data cleanup
      nil
    end

    # By default, zero byte/empty files are ignored.  This method can be overridden if a case is encountered where we
    # do something with a file based on its name only, and don't actually care about its content.
    def process_zero_byte_files?
      false
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
        log.receipt_location = original_receipt_location(abbrev_key)
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
        log.process_status = log.assess_process_status_from_messages
        log.process_end_date = Time.zone.now
        # 'force_inbound_file_logging' option allows for short-term logging of inbound file records for parsers that
        # may have the function disabled normally.
        log.save! if (log_file?(log.s3_bucket, log.s3_path) || opts[:force_inbound_file_logging])
      end

      def original_receipt_location s3_key
        # Receipt location should be the system folder / parser name.  It shouldn't include dates, etc.
        # In essence, it's the ftp path of the file - which allows us to use it for rerpocessing later.
        # The s3 key looks like this: 2018-10/02/www-vfitrack-net/kewill_statements
        # The YYYY-MM/DD value is added to make the files easy to retrieve from the archive and is simply prepended
        # to the actual path of the file on the ftp system.  So to get the original path, all we need to do is strip the
        # YYYY-MM/DD if it's there.

        # The easiest way to do this is to just deconstruct the path and strip the filename leading YYYY-MM/DD elements
        location = s3_key.to_s
        if location =~ /^\d{4}-\d{2}([\/\\])\d{2}[\/\\]/
          return Pathname.new(location).each_filename.to_a[2..-2].join($1)
        end

        location
      end

      # Returns true if the data object is nil or length zero, assuming the length of that data can be assessed.
      # Handles a small minority of parsers that override retrieve_file_data to return things like
      # Zip::InputStreams, which don't have a length method.
      def file_empty? data
        data.nil? || (data.respond_to?(:length) && data.length == 0)
      end
  end

end; end
