module OpenChain; module EntityCompare; module ProductVendorAssignmentComparator
  extend ActiveSupport::Concern

  def accept? snapshot
    return snapshot.recordable_type == "ProductVendorAssignment"
  end

end; end; end