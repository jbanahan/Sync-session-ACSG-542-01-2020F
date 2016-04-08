module OpenChain; module EntityCompare; module OrderComparator
  extend ActiveSupport::Concern

  def accept? snapshot
    return snapshot.recordable_type == "Order"
  end

end; end; end