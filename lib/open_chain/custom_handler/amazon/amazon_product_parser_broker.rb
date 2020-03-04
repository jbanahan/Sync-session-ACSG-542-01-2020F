require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/amazon/amazon_product_parser'
require 'open_chain/custom_handler/amazon/amazon_fda_product_parser'
require 'open_chain/custom_handler/amazon/amazon_fda_rad_product_parser'
require 'open_chain/custom_handler/amazon/amazon_cvd_add_product_parser'
require 'open_chain/custom_handler/amazon/amazon_lacey_product_parser'
require 'open_chain/custom_handler/amazon/amazon_product_documents_parser'

# Amazon sends us a whole bunch of different product csv files, and they're all going to end up
# in the same source directory.  The whole point of this class is to determine
# which ACTUAL product file they sent and then send the data through to the parser 
# that handles that file type.
module OpenChain; module CustomHandler; module Amazon; class AmazonProductParserBroker
  include OpenChain::IntegrationClientParser

  def self.parse data, opts = {}
    parser = get_parser(opts[:key])
    # We want to update the inbound file that the integration client parser provides and 
    # rekey it to the actual parser utilized.
    inbound_file.parser_name = parser.to_s

    parser.parse(data, opts)
  end

  def self.get_parser full_path
    # Amazon uses a unique file naming structure for all files coming into the sytsem
    # These will be parts files, OGA data the parts and file attachments for the parts.

    # Each file has a unique naming style we will utilize to determine which parser to use
    filename = File.basename(full_path)

    if filename =~ /^US_COMPLIANCE_.+\.csv$/i
      # Parts File -> <DESTINATION_COUNTRY>_COMPLIANCE_<UNIQUE_ID>_<DATE>.csv
      return OpenChain::CustomHandler::Amazon::AmazonProductParser
    elsif filename =~ /^US_PGA_([^_]+)_.+\.csv$/i
      # PGA Data File -> <DESTINATION_COUNTRY>_PGA_<PGA_CODE>_<UNIQUE_ID>_DATE.csv
      oga_code = $1.to_s.upcase
      case oga_code
      when "FDG", "FCT"
        return OpenChain::CustomHandler::Amazon::AmazonFdaProductParser
      when "RAD"
        return OpenChain::CustomHandler::Amazon::AmazonFdaRadProductParser
      when "CVD", "ADD"
        # I don't actually know how the CVD / ADD part files are going to be named...we don't have 
        # sample files for them, so it's just a best guess.  The detection algorithm for them might
        # have to change here.
        return OpenChain::CustomHandler::Amazon::AmazonCvdAddProductParser
      when "ALG"
        return OpenChain::CustomHandler::Amazon::AmazonLaceyProductParser
      else
        inbound_file.reject_and_raise "No parser exists to handle Amazon #{oga_code} OGA file types."
      end
      
    elsif filename =~ /^US_.+_PGA_/i
      # Docs File -> <DESTINATION_COUNTRY>_<IOR_ID>_<SKU>_<MANUFACTURERNAME>_PGA_<PGA_CODE>_<DOCUMENT_NAME>_<DATE>.<FILE_EXTENSION>
      return OpenChain::CustomHandler::Amazon::AmazonProductDocumentsParser
    else
      inbound_file.reject_and_raise "No parser exists to handle Amazon files named like '#{filename}'."
    end

  end
end; end; end; end