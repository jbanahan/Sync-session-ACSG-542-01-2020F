module OpenChain; module CustomHandler; module LumberLiquidators; class LumberOrderCloser
  def self.go order_numbers, user
    open_count = open_closed_orders order_numbers, user
    close_count = close_orders order_numbers, user
    send_completion_message open_count, close_count, user
  end
  def self.open_closed_orders order_numbers, user
    orders = Order.where('order_number IN (?)',order_numbers).where('closed_at is not null')
    orders.each do |o|
      o.reopen! user
    end
  end

  def self.close_orders order_numbers, user
    orders = Order.where('order_number NOT IN (?)',order_numbers).where('closed_at is null')
    orders.each do |o|
      o.close! user
    end
  end

  def self.send_completion_message open_count, close_count, user
  end
end; end; end; end
