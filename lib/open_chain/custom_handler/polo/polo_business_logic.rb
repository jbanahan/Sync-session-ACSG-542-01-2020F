module OpenChain; module CustomHandler; module Polo
  module PoloBusinessLogic

    def sap_po? po_number
      po_number =~ /^\s*47/
    end

    # Splits an SAP PO / Line number combination into a correctly formatted 
    def split_sap_po_line_number po_number
      if po_number =~ /^(.+)-(\d+)$/
        po = $1
        line_number = $2

        # Now we need to make sure there's at least one trailing zero
        unless line_number.ends_with? "0"
          line_number += "0"
        end

        # Strip all leading zeros
        line_number = (line_number =~ /^0+(\d+)$/) ? $1 : line_number

        [po, line_number]
      else
        [po_number, ""]
      end
    end

    def prepack_indicator? value
      value.respond_to?(:upcase) && "AS" == value.upcase.strip
    end
    
  end
end; end; end