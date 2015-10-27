module OpenChain; module EntityCompare; class CascadeProductValidations
  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    return unless type=='Product'

    p = Product.find(id)

    orders = p.order_lines.collect {|ol| ol.order}.uniq
    orders.each do |o|
      BusinessValidationTemplate.create_results_for_object! o
    end

    shipments = p.shipment_lines.collect {|sl| sl.shipment}.uniq
    shipments.each do |s|
      BusinessValidationTemplate.create_results_for_object! s
    end
  end
end; end; end