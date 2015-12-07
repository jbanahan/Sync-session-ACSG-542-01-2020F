module OpenChain; module CustomHandler; module LumberLiquidators; class LumberViewSelector
  def self.order_view order, user
    '/custom_view/ll/order_view.html'
  end
end; end; end; end