module OpenChain; module EntityCompare; module SecurityFilingComparator
  extend ActiveSupport::Concern

  def accept? snapshot
    return snapshot.recordable_type == "SecurityFiling"
  end

end; end; end