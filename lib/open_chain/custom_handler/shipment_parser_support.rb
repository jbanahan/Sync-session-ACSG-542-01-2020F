module OpenChain; module CustomHandler; module ShipmentParserSupport 

  def flag_unaccepted order_nums
    OrdersChecker.flag_unaccepted order_nums
  end

  def warn_for_bookings order_nums, shipment
    OrdersChecker.warn_for_bookings order_nums, shipment
  end

  def warn_for_manifest order_nums, shipment
    OrdersChecker.warn_for_manifest order_nums, shipment
  end

  module OrdersChecker
    
    def self.flag_unaccepted order_nums
      return unless Array.wrap(order_nums).length > 0

      unaccepted_orders = Order.where(order_number: order_nums)
                               .where(%Q(approval_status <> "Accepted" OR approval_status IS NULL))
                               .pluck(:customer_order_number)
      if unaccepted_orders.present?
        raise_error(%Q(This file cannot be processed because the following orders are in an "unaccepted" state: #{unaccepted_orders.join(", ")}))
      end
    end

    def self.warn_for_bookings order_nums, shipment
      warn :orders_on_multi_bookings, order_nums, shipment
    end

    def self.warn_for_manifest order_nums, shipment
      warn :orders_on_multi_manifests, order_nums, shipment
    end

    def self.orders_with_mismatched_transport_mode order_nums, shipment
      Order.where(order_number: order_nums, importer_id: shipment.importer_id)
           .where(%Q(mode <> "#{shipment.normalized_booking_mode}"))
           .pluck(:customer_order_number)
    end

    def self.orders_on_multi_manifests order_nums, reference
      r = ActiveRecord::Base.connection.execute multi_manifests_qry(order_nums, reference)
      compile_multi_matches r
    end

    def self.orders_on_multi_bookings order_nums, reference
      r = ActiveRecord::Base.connection.execute multi_bookings_qry(order_nums, reference)
      compile_multi_matches r
    end

    private

    def self.warn order_retrieval_meth, order_nums, shipment
      return unless Array.wrap(order_nums).length > 0
      assigned_to_multi_shp = send(order_retrieval_meth, order_nums, shipment.reference)
      mode_mismatch = orders_with_mismatched_transport_mode order_nums, shipment
      if assigned_to_multi_shp.present? || mode_mismatch.present?
        raise_formatted_exception(assigned_to_multi_shp, mode_mismatch )
      end
    end

    def self.raise_formatted_exception assigned_to_multi_shp, mode_mismatch
      # BE SURE TO UPDATE PROCESS_MANIFEST_CTRL.COFFEE IF YOU CHANGE THIS ERROR MESSAGE!!
      msg = []
      if assigned_to_multi_shp.count > 0
        partly_flattened = assigned_to_multi_shp.map{ |ord,shps| "#{ord} (#{shps.join(', ')})" }
        msg << "The following purchase orders are assigned to other shipments: #{partly_flattened.join(', ')}" 
      end
      
      if mode_mismatch.count > 0
        msg << "The following purchase orders have a mode of transport that doesn't match the assigned shipment: #{mode_mismatch.join(', ')}" 
      end
      raise_error(msg.join(" *** ")) if msg.present?
    end

    def self.multi_manifests_qry order_nums, reference
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

    def self.multi_bookings_qry order_nums, reference
      <<-SQL
        SELECT DISTINCT o.customer_order_number, s.reference
        FROM orders o
          INNER JOIN booking_lines bl ON o.id = bl.order_id
          INNER JOIN shipments s ON s.id = bl.shipment_id
        WHERE o.order_number IN (#{order_nums.map{ |o| "\"#{o}\""}.join(",")}) AND s.reference <> "#{reference}"
        ORDER BY o.customer_order_number, s.reference
      SQL
    end

    def self.compile_multi_matches results
      out = Hash.new{ |k,v| k[v] = [] }
      results.each{ |r| out[r[0]] << r[1] }
      out
    end

    
    def self.raise_error message
      if InstanceInformation.webserver?
        raise UnreportedError, message
      else
        raise message
      end
    end

  end

  # This is just a dumb bit of code to raise unreported errors when run on the webservers, so we don't get notifications
  # of them (user still sees them on screen), but raise standard errors when run from a job queue (if run that way.)
  def raise_error message
    OrdersChecker.raise_error message
  end

end; end; end;
