module OpenChain; module EntityCompare; module InvoiceComparator
  extend ActiveSupport::Concern

  def accept? snapshot
    return snapshot.recordable_type == "Invoice"
  end

end; end; end