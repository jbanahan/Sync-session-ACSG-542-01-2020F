class OrderFromFix
  def up
    user = User.integration
    company_cache = make_company_cache
    company_cache.each do |vendor_id,order_from_id|
      ords = Order.where(vendor_id:vendor_id).where('orders.order_from_address_id is null OR NOT orders.order_from_address_id = ?',order_from_id)
      ords.each do |o|
        o.update_attributes(order_from_address_id:order_from_id)
        o.create_snapshot(user,nil,"Order from bulk update.")
      end
    end
  end

  def make_company_cache
    cache = {}
    Address.where("system_code LIKE '%-CORP'").each do |a|
      cache[a.company_id] = a.id
    end
    cache
  end
end
