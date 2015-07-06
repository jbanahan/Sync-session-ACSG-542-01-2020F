require 'open_chain/xml_builder'
require 'open_chain/ftp_file_support'

module OpenChain; module CustomHandler; class ISFXMLGenerator
  include OpenChain::XmlBuilder
  include OpenChain::FtpFileSupport
end; end; end