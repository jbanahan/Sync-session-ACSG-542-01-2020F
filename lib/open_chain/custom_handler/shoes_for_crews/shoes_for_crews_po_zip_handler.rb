require 'open_chain/integration_client_parser'
require 'open_chain/s3'
require 'open_chain/ftp_file_support'

# This is pretty much just a class that unzips a zip file, extracts everything from it
# and sends all those files back to an ftp folder - where the other SFC PO handler will 
# eventually process them.
module OpenChain; module CustomHandler; module ShoesForCrews; class ShoesForCrewsPoZipHandler
  extend OpenChain::IntegrationClientParser
  extend OpenChain::FtpFileSupport

  def self.process_from_s3 bucket, key, opts = {}
    OpenChain::S3.download_to_tempfile(bucket, key) do |tempfile|
      process_file tempfile
    end
  end

  def self.process_file file
    Zip::File.open(file.path) do |zip|
      zip.each do |zip_entry|
        filename = File.basename(zip_entry.name)
        next unless File.extname(zip_entry.name).to_s.upcase == ".XLS"

        Tempfile.open([File.basename(filename, ".*"), File.extname(filename)]) do |t|
          t.binmode
          t.write(zip_entry.get_input_stream.read)
          t.flush

          t.rewind
          Attachment.add_original_filename_method(t, filename)
          send_file(t)
        end
      end
    end
  end

  def self.send_file file
    ftp_file file, connect_vfitrack_net("_shoes_po")
  end

end; end; end; end