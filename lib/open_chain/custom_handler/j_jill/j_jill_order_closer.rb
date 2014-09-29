module OpenChain; module CustomHandler; module JJill; class JJillOrderCloser
  def self.run_schedulable opts={}
    jill = Company.find_by_system_code 'JJILL'
    return unless jill
    self.new.process_orders jill.importer_orders.not_closed, User.integration
  end
  def close? order
    return true if order.ship_window_end && (0.seconds.ago.to_i - order.ship_window_end.to_time.to_i) > 60.days
    return true if (order.shipped_qty.to_f / order.ordered_qty.to_f) >= 0.95
    return false
  end

  def process_orders orders, user
    orders.each {|o| o.close!(user) if close?(o)}
  end


end; end; end; end