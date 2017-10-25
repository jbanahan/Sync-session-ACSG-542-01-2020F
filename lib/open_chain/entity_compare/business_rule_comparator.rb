module OpenChain; module EntityCompare; module BusinessRuleComparator
  extend ActiveSupport::Concern

  def accept? snapshot
    return snapshot.kind_of? BusinessRuleSnapshot
  end

end; end; end