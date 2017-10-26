module OpenChain; module EntityCompare; module BusinessRuleComparator
  extend ActiveSupport::Concern

  def accept? snapshot
    true
  end

end; end; end