class HistoryWalker
  
  def initialize
    @registered_listeners = Hash.new
    register(:object_change, IcsListener.new)
  end
  
  def register(history_type,listener)
    if @registered_listeners[history_type].nil?
      @registered_listeners[history_type] = []
    end
    @registered_listeners[history_type] << listener
  end
  
  def registered(history_type)
    if @registered_listeners[history_type].nil?
      @registered_listeners[history_type] = []
    end
    return @registered_listeners[history_type]
  end
  
  def walk
    History.where(:walked => nil).each do |h|
      registered(h.history_type.intern).each do |listener|
        listener.consume h
      end
      h.walked = Time.now
      h.save
    end
  end
end

class IcsListener
  def consume(h)
    subs = ItemChangeSubscription.where({:order_id => h.order_id, :shipment_id => h.shipment_id, :product_id => h.product_id})
    subs.each do |s|
      if s.app_message?
        send_app_message(h,s)
      end
      if s.email?
        text_only = !s.user.email_format.nil? && s.user.email_format=="text"
        OpenMailer.send_change(h,s,text_only).deliver
      end
    end
  end
  
  private
  
  def send_app_message(h,s)
      m = Message.new
      m.user = s.user
      m.subject = make_subject(h)
      m.body = make_body(h)
      m.save    
  end
  def make_subject(h)
    details = h.details_hash
    type = details[:type].nil? ? "Item" : details[:type]
    identifier = details[:identifier].nil? ? "[unknown]" : details[:identifier]
    return "#{type} #{identifier} changed."
  end
  
  def make_body(h)
    details = h.details_hash
    type = details[:type].nil? ? "Item" : details[:type]
    identifier = details[:identifier].nil? ? "[unknown]" : details[:identifier]
    link = details[:link].nil? ? identifier : "<a href='#{details[:link]}'>#{identifier}</a>"
    r = "<p>#{type} #{link} changed.</p>"
    details.each do |k,v|
      if(k!=:link && k!=:type && k!=:identifier)
        r << "<p>#{k.to_s}: #{v}</p>"
      end
    end
    return r
  end
  
end