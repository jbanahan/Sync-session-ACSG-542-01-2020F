require 'open_chain/custom_handler/fenix_invoice_generator'

module OpenChain; module CustomHandler; module Polo
  class PoloCaFenixInvoiceGenerator
    include OpenChain::CustomHandler::FenixInvoiceGenerator

    RL_CA_FACTORY_STORE_TAX_ID ||= "806167003RM0002"

    def invoice_header_map
      # At least for the moment, the commercial invoice we get from Polo doesn't really have actual invoice numbers
      # Just make one up that should be unique at least to get it into the system.
      default_invoice_header_map.merge({
        :invoice_number => lambda {|i| "VFI-#{i.id}"},
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
