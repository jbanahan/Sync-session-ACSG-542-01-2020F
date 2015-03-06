module OpenChain; module ModelFieldDefinition; module SaleFieldDefinition
  def add_sale_fields
    add_fields CoreModule::SALE, [
      [1,:sale_order_number,:order_number,"Sale Number",{:data_type=>:string}],
      [2,:sale_order_date,:order_date,"Sale Date",{:data_type=>:date}],
    ]
    add_fields CoreModule::SALE, make_customer_arrays(100,"sale","sales_orders")
    add_fields CoreModule::SALE, make_ship_to_arrays(200,"sale","sales_orders")
    add_fields CoreModule::SALE, make_division_arrays(300,"sale","sales_orders")
    add_fields CoreModule::SALE, make_master_setup_array(400,"sale")
  end
end; end; end
