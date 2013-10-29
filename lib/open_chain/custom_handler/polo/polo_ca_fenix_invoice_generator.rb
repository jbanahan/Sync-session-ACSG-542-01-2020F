require 'open_chain/custom_handler/fenix_invoice_generator'

module OpenChain; module CustomHandler; module Polo
  class PoloCaFenixInvoiceGenerator < FenixInvoiceGenerator

    def invoice_header_map
      # At least for the moment, the commercial invoice we get from Polo doesn't really have actual invoice numbers
      # Just make one up that should be unique at least to get it into the system.
      super.merge({
        :invoice_number => lambda {|i| "VFI-#{i.id}"},
      })
    end

    def self.generate invoice_id
      PoloCaFenixInvoiceGenerator.new.generate_and_send invoice_id
    end

  end
end; end; end
