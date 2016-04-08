module OpenChain; module EntityCompare; module EntryComparator
  extend ActiveSupport::Concern

  def accept? snapshot
    return snapshot.recordable_type == "Entry"
  end

end; end; end