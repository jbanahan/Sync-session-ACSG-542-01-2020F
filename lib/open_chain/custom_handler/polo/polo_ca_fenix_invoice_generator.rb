require 'open_chain/custom_handler/fenix_invoice_generator'

module OpenChain; module CustomHandler; module Polo
  class PoloCaFenixInvoiceGenerator
    include OpenChain::CustomHandler::FenixInvoiceGenerator

    RL_CA_FACTORY_STORE_TAX_ID ||= "806167003RM0002"

    def invoice_header_map
      # The commercial invoice we get from Polo may not have an actual invoice number.
      # If that's the case, just make one up.
      default_invoice_header_map.merge({
        :invoice_number => lambda {|i| i.invoice_number.blank? ? "VFI-#{i.id}" : i.invoice_number},
        # There's an issue in Fenix with attaching importer information to these things for now and 
        # the system is importing the data into the wrong account. Until it's resolved, we're going to leave
        # the importer information blank in the file.
        :importer => {}
      })
    end

    def invoice_detail_map
      default_invoice_detail_map
    end

    def fenix_customer_code
      RL_CA_FACTORY_STORE_TAX_ID
    end

    def self.generate invoice_id
      PoloCaFenixInvoiceGenerator.new.generate_and_send invoice_id
    end

  end
end; end; end