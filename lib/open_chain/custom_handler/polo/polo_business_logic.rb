module OpenChain; module CustomHandler; module Polo
  module PoloBusinessLogic

    def sap_po? po_number
      po_number =~ /^\s*47/
    end
    
  end
end; end; end