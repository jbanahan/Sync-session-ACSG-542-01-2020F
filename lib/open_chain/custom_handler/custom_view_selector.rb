module OpenChain; module CustomHandler; class CustomViewSelector
  def self.register_handler handler
    @@handler = handler
  end
  def self.order_view order, user
    @@handler ||= false
    if @@handler && @@handler.respond_to?(:order_view)
      return @@handler.order_view(order,user)
    end
    return nil
  end
  def self.shipment_view shipment, user
    @@handler ||= false
    if @@handler && @@handler.respond_to?(:shipment_view)
      return @@handler.shipment_view(shipment,user)
    end
    return nil
  end
end; end; end
