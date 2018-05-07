module OpenChain; module Registries; class DefaultOrderAcceptanceRegistry

  def self.can_be_accepted? order
    true
  end

  def self.can_accept? order, user
    return user.admin? ||
      (
        (user.company == order.vendor || user.company == order.agent)  &&
        user.in_group?('ORDERACCEPT')
      )
  end

end; end; end;