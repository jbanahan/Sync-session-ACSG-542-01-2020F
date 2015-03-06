module OpenChain; module ModelFieldDefinition; module DeliveryLineFieldDefinition
  def add_delivery_line_fields
    add_fields CoreModule::DELIVERY_LINE, [
      [1,:delln_line_number,:line_number,"Delivery Row",{:data_type=>:integer}],
      [2,:delln_delivery_qty,:quantity,"Delivery Row Quantity",{:data_type=>:decimal}]
    ]
    add_fields CoreModule::DELIVERY_LINE, make_product_arrays(100,"delln","delivery_lines")
  end
end; end; end
