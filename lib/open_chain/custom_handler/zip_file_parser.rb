require 'open_chain/integration_client_parser'

# Base file parser class that expects to be dealing with a zip file.
# Extenders must implement the method 'process_zip_content'.
module OpenChain; module CustomHandler; class ZipFileParser
  include OpenChain::IntegrationClientParser

  def self.parse_file zip_stream, log, opts = {}
    attempts = opts[:attempt_count].presence || 1
    self.new.process_file zip_stream, log.s3_bucket, log.s3_path, attempts
  end

  def self.retrieve_file_data bucket, key, _opts = {}
    OpenChain::S3.download_to_tempfile(bucket, key)
  end

  def self.post_process_data data
    # Close! is called here to clean up the tempfile, assuming we're working with a tempfile.
    data.close! if data&.respond_to?(:close!) && !data.closed?
  end

  def process_file zip_file, s3_bucket, s3_key, attempt_count
    # The name/path of the zip file is not the original name of the file when it was sent to us: the pick-up
    # routine attaches some other crud for the sake of uniqueness.  We can get that original name, however, from the
    # S3 key/path.
    original_zip_file_name = original_file_name s3_key
    unzipped_contents = unzip_file zip_file
    if unzipped_contents.length > 0
      process_zip_content original_zip_file_name, unzipped_contents, zip_file, s3_bucket, s3_key, attempt_count
    else
      handle_empty_file original_zip_file_name, zip_file
    end
    nil
  end

  # Override to allow only specific file types to be included in the files extracted from the zip.
  def include_file? _zip_entry
    true
  end

  def handle_empty_file zip_file_name, zip_file
    # Does nothing by default.  Override to send email, log error, etc.
  end

  # This is a workaround for the convenience developer method, IntegrationClientParser#process_from_file, to work
  # nicely with zip fileparsing.  Due to how unzipping is handled, handle_processing needs to be passed the actual
  # file object rather than the content of the file, which is what the default version of this method provides.
  def self.get_process_from_file_data file
    file
  end

  # Default behavior is to simply log the error.  Override for custom functionality.
  def handle_zip_error error
    inbound_file.add_reject_message error.message
    nil
  end

  private

    def original_file_name s3_key
      File.basename(self.class.get_s3_key_without_timestamp(s3_key))
    end

    # Unzips the file, returning an array of ZipFiles.
    def unzip_file zip_file
      zip_file_contents = []
      begin
        Zip::File.open(zip_file.path) do |unzipped_zip_file|
          unzipped_zip_file.each do |zip_entry|
            if include_file?(zip_entry)
              zip_file_contents << zip_entry
            end
          end
        end
      rescue Zip::Error => e
        handle_zip_error e
      end
      zip_file_contents
    end

    def write_zip_entry_to_temp_file zip_content_file, output_file_name
      filename = File.basename(zip_content_file.name)
      Tempfile.open([File.basename(filename, ".*"), File.extname(filename)]) do |t|
        t.binmode
        t.write(zip_content_file.get_input_stream.read)
        t.flush
        t.rewind
        Attachment.add_original_filename_method t, output_file_name
        yield t
      end
      nil
    end

end; end; end