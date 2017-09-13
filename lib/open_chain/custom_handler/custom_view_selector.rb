module OpenChain; module CustomHandler; class CustomViewSelector
  def self.register_handler handler
    @@handler = handler
  end
  def self.order_view order, user
    @@handler ||= false
    if @@handler && @@handler.respond_to?(:order_view)
      return add_cache_parameter(@@handler.order_view(order,user))
    end
    return nil
  end
  def self.shipment_view shipment, user
    @@handler ||= false
    if @@handler && @@handler.respond_to?(:shipment_view)
      return add_cache_parameter(@@handler.shipment_view(shipment,user))
    end
    return nil
  end


  def self.add_cache_parameter view_url, cache_value: MasterSetup.current_code_version
    return nil if view_url.blank?

    # What we're doing here is adding a uniqueness factor onto the view url, 
    # so that the angular templates don't cache the pages to long..we'll use 
    # the current code version as the cache.
    uri = URI.parse view_url
    cache_param = "c=#{URI::encode(cache_value)}"
    if uri.query.blank?
      uri.query = cache_param
    else
      uri.query = uri.query + "&#{cache_param}"
    end

    uri.to_s
  end
end; end; end
