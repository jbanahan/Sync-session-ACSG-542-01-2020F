module OpenChain; module EntityCompare; class CascadeProductValidations
  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    return unless type=='Product'

    p = Product.where(id: id).first
    # It's possible a product could be deleted after a change record is queued and before it's processed,
    # handle this scenario
    return if p.nil?

    validate_connected_orders p
    validate_connected_shipments p
  end


  def self.validate_connected_orders product
    # Do this with batched lookups, otherwise there's a possibility of 10's of thousands of orders
    # flooding in here and crashing the queue
    Order.joins(:order_lines).where(order_lines: {product_id: product.id}).uniq.find_each do |order|
      BusinessValidationTemplate.create_results_for_object! order
    end
  end

  def self.validate_connected_shipments product
    # Do this with batched lookups, otherwise there's a possibility of 10's of thousands of shipments
    # flooding in here and crashing the queue
    Shipment.joins(:shipment_lines).where(shipment_lines: {product_id: product.id}).uniq.find_each do |shipment|
      BusinessValidationTemplate.create_results_for_object! shipment
    end
  end

end; end; end