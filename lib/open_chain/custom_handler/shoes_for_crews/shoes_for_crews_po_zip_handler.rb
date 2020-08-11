require 'open_chain/custom_handler/zip_file_parser'
require 'open_chain/ftp_file_support'

# This is pretty much just a class that unzips a zip file, extracts everything from it
# and sends all those files back to an ftp folder - where the other SFC PO handler will
# eventually process them.
module OpenChain; module CustomHandler; module ShoesForCrews; class ShoesForCrewsPoZipHandler < OpenChain::CustomHandler::ZipFileParser
  include OpenChain::FtpFileSupport

  def process_zip_content _original_zip_file_name, unzipped_contents, _zip_file, _s3_bucket, _s3_key, _attempt_count
    unzipped_contents.each do |zip_entry|
      filename = File.basename(zip_entry.name)
      if File.extname(zip_entry.name).to_s.upcase == ".XLS"
        inbound_file.add_info_message("Extracted file #{filename}")

        write_zip_entry_to_temp_file(zip_entry, filename) do |t|
          ftp_file t, connect_vfitrack_net("_shoes_po")
        end
      end
    end
    nil
  end

end; end; end; end