module OpenChain; module CustomHandler; module ShipmentParserSupport 
  def orders_on_multi_manifests order_nums, reference
    orders :multi_manifests_qry, order_nums, reference
  end

  def orders_on_multi_bookings order_nums, reference
    orders :multi_bookings_qry, order_nums, reference
  end

  def orders meth, order_nums, reference
    r = ActiveRecord::Base.connection.execute send(meth, order_nums, reference)
    # BE SURE TO UPDATE PROCESS_MANIFEST_CTRL.COFFEE IF YOU CHANGE THIS ERROR MESSAGE!!
    raise "ORDERS FOUND ON MULTIPLE SHIPMENTS: ~#{compile_matches r}" if r.count > 0
  end

  def multi_manifests_qry order_nums, reference
    <<-SQL
      SELECT DISTINCT o.customer_order_number, s.reference
      FROM orders o
        INNER JOIN order_lines ol ON o.id = ol.order_id
        INNER JOIN piece_sets ps ON ps.order_line_id = ol.id
        INNER JOIN shipment_lines sl ON sl.id = ps.shipment_line_id
        INNER JOIN shipments s ON s.id = sl.shipment_id
      WHERE o.order_number IN (#{order_nums.map{ |o| "\"#{o}\""}.join(",")}) AND s.reference <> "#{reference}"
      ORDER BY o.customer_order_number, s.reference
    SQL
  end

  def multi_bookings_qry order_nums, reference
    <<-SQL
      SELECT DISTINCT o.customer_order_number, s.reference
      FROM orders o
        INNER JOIN booking_lines bl ON o.id = bl.order_id
        INNER JOIN shipments s ON s.id = bl.shipment_id
      WHERE o.order_number IN (#{order_nums.map{ |o| "\"#{o}\""}.join(",")}) AND s.reference <> "#{reference}"
      ORDER BY o.customer_order_number, s.reference
    SQL
  end

  def compile_matches results
    out = Hash.new{ |k,v| k[v] = [] }
    results.each{ |r| out[r[0]] << r[1] }
    out.to_json
  end

end; end; end;
