require 'open_chain/integration_client_parser'
require 'open_chain/s3'
require 'open_chain/ftp_file_support'

# This is pretty much just a class that unzips a zip file, extracts everything from it
# and sends all those files back to an ftp folder - where the other SFC PO handler will
# eventually process them.
module OpenChain; module CustomHandler; module ShoesForCrews; class ShoesForCrewsPoZipHandler
  include OpenChain::IntegrationClientParser
  include OpenChain::FtpFileSupport

  def self.retrieve_file_data bucket, key, opts = {}
    io = StringIO.new
    io.binmode
    OpenChain::S3.get_data(bucket, key, io)
    io.rewind
    Zip::InputStream.open(io)
  end

  def self.parse_file zip_stream, log, opts = {}
    self.new.parse_file zip_stream, log, opts
  end

  def parse_file zip_stream, log, opts = {}
    while(zip_entry = zip_stream.get_next_entry)
      filename = File.basename(zip_entry.name)
      if File.extname(zip_entry.name).to_s.upcase == ".XLS"
        log.add_info_message("Extracted file #{filename}")

        Tempfile.open([File.basename(filename, ".*"), File.extname(filename)]) do |t|
          t.binmode
          t.write(zip_entry.get_input_stream.read)
          t.flush

          t.rewind
          Attachment.add_original_filename_method(t, filename)
          ftp_file t, connect_vfitrack_net("_shoes_po")
        end
      end
    end
  end

end; end; end; end