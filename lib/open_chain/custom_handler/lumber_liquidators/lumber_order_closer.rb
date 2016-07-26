module OpenChain; module CustomHandler; module LumberLiquidators; class LumberOrderCloser
  def self.can_view? user
    MasterSetup.get.custom_feature?('Lumber Order Close') && (user.admin? || user.in_group?('ORDER_CLOSE'))
  end
  # uses primitives for better delayed job serialization
  def self.process s3_path, effective_date, user_id
    bucket = OpenChain::S3.bucket_name
    data = OpenChain::S3.get_data(bucket,s3_path)
    order_numbers = data.lines.each {|ln| ln.chomp!}
    go(order_numbers, effective_date, User.find(user_id))
    OpenChain::S3.delete bucket, s3_path
  end

  def self.go order_numbers, effective_date, user
    Lock.acquire('LumberOrderCloser',{timeout:600,lock_expiration:600}) do
      open_count = open_closed_orders order_numbers, user
      close_count = close_orders order_numbers, effective_date, user
      send_completion_message open_count, close_count, user
    end
  end
  def self.open_closed_orders order_numbers, user
    orders = Order.where('order_number IN (?)',order_numbers).where('closed_at is not null')
    orders.each do |o|
      o.reopen! user
    end
  end

  def self.close_orders order_numbers, effective_date, user
    orders = Order.where('order_number NOT IN (?) and order_date < ?', order_numbers, effective_date).where('closed_at is null')
    orders.each do |o|
      o.close! user
    end
  end

  def self.send_completion_message open_count, close_count, user
    user.messages.create!(subject:"Order Close Job Complete", body:"#{open_count.size} orders were re-opened, and #{close_count.size} orders were closed.")
  end

end; end; end; end
