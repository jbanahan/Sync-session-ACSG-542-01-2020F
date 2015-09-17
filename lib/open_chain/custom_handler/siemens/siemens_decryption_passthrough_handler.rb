require 'open_chain/custom_handler/gpg_decrypt_passthrough_support'
require 'open_chain/gpg'
require 'open_chain/integration_client_parser'

module OpenChain; module CustomHandler; module Siemens; class SiemensDecryptionPassthroughHandler
  include OpenChain::CustomHandler::GpgDecryptPassthroughSupport

  attr_reader :filetype

  def process_from_s3 bucket, remote_path, original_filename: nil
    # Siemens tosses some other types of files we don't care about in this folder...just skip them.
    filetype = get_filetype(remote_path, original_filename)
    return nil unless filetype
    
    @filetype = filetype
    super
  end

  def ftp_credentials
    case @filetype
    when :product
      fenixapp_vfitrack_net("Incoming/Parts/SIEMENS/Incoming")
    when :vendor
      fenixapp_vfitrack_net("Incoming/Vendors/SIEMENS/Incoming")
    else
      raise "Unexpected Siemens filetype of '#{@filetype}' found."
    end
  end

  def gpg_helper
    OpenChain::GPG.new("config/siemens.asc", "config/vfi-canada.asc")
  end

  def gpg_passphrase
    # This ideally ends up in the secrets.yml file when we go to Rails 4...in the interest of getting things done..it's in the code for now
    "R!ch2805"
  end

  private 
    def get_filetype remote_path, original_filename = nil
      filename = File.basename(original_filename.presence || remote_path).to_s.upcase

      if filename.starts_with?("CAXPR")
        file_type = :product
      elsif filename.starts_with?("VENDOR")
        file_type = :vendor
      end

      return file_type
    end

end; end; end; end;