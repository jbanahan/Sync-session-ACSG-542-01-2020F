module OpenChain; module CustomHandler; class CustomViewSelector
  def self.register_handler handler
    @@handler = handler
  end
  def self.order_view order, user
    if @@handler && @@handler.respond_to?(:order_view)
      return @@handler.order_view(order,user)
    end
    return nil
  end
end; end; end