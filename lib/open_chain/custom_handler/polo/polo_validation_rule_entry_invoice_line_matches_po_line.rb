module OpenChain; module CustomHandler; module Polo; class PoloValidationRuleEntryInvoiceLineMatchesPoLine < ValidationRuleEntryInvoiceLineMatchesPoLine

  def extract_po_number invoice_line
    if invoice_line.po_number.to_s =~ /\A(\d+)(?:-(\d+))?\z/
      $1
    else
      invoice_line.po_number
    end
  end

end; end; end; end;