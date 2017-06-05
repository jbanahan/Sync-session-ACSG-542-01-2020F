module OpenChain; module EntityCompare; module ProductComparator
  extend ActiveSupport::Concern

  def accept? snapshot
    return snapshot.recordable_type == "Product"
  end

end; end; end   