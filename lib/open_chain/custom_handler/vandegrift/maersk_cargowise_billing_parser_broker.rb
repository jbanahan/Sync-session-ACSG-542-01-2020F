require 'open_chain/integration_parser_broker'
require 'open_chain/custom_handler/vandegrift/cargowise_xml_support'
require 'open_chain/custom_handler/intacct/intacct_cargowise_freight_billing_file_parser'
require 'open_chain/custom_handler/vandegrift/maersk_cargowise_broker_invoice_file_parser'

module OpenChain; module CustomHandler; module Vandegrift; class MaerskCargowiseBillingParserBroker
  include OpenChain::IntegrationParserBroker
  include OpenChain::CustomHandler::Vandegrift::CargowiseXmlSupport

  # Since some of these cargowise xml files can be massive, this is really just here to avoid having
  # to parse the billing data once to determine what parser
  # is utilized and then again to actual parser the file.  Each parser utilized is aware that it
  # might recieve raw file data or an XML document.
  def self.pre_process_data data
    xml_document(data)
  end

  def self.create_parser _bucket, _key, data, _opts
    self.new.create_parser data
  end

  def create_parser document
    doc = unwrap_document_root(document)

    company_code = first_text(doc, "UniversalTransaction/TransactionInfo/DataContext/Company/Code")

    if company_code.to_s.upcase == "VDR"
      OpenChain::CustomHandler::Intacct::IntacctCargowiseFreightBillingFileParser.new
    else
      MaerskCargowiseBrokerInvoiceFileParser.new
    end
  end

end; end; end; end