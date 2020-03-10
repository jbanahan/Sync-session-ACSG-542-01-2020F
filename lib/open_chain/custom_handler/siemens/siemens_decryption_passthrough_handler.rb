require 'open_chain/custom_handler/gpg_decrypt_passthrough_support'
require 'open_chain/gpg'
require 'open_chain/integration_client_parser'

module OpenChain; module CustomHandler; module Siemens; class SiemensDecryptionPassthroughHandler
  include OpenChain::CustomHandler::GpgDecryptPassthroughSupport
  include OpenChain::IntegrationClientParser

  attr_reader :filetype

  def self.process_from_s3 bucket, remote_path, opts = {}
    filetype = get_filetype(remote_path, opts[:original_filename])
    if !filetype.nil?
      return super
    else 
      return nil
    end
  end

  def ftp_credentials
    # We can use the filename from the inbound log to determine the file type
    log = inbound_file
    filetype = self.class.get_filetype(log.file_name)
    case filetype
    when :product
      connect_vfitrack_net("to_ecs/siemens/parts")
    when :vendor
      connect_vfitrack_net("to_ecs/siemens/vendors")
    else
      log.error_and_raise "Unexpected Siemens filetype of '#{filetype}' found."
    end
  end

  def gpg_secrets_key
    "vfi_canada"
  end

  private 
    def self.get_filetype remote_path, original_filename = nil
      filename = File.basename(original_filename.presence || remote_path).to_s.upcase

      if filename.starts_with?("CAXPR")
        file_type = :product
      elsif filename.starts_with?("VENDOR")
        file_type = :vendor
      end

      return file_type
    end

end; end; end; end;