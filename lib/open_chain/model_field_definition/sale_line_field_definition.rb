module OpenChain; module ModelFieldDefinition; module SaleLineFieldDefinition
  def add_sale_line_fields
    add_fields CoreModule::SALE_LINE, [
      [1,:soln_line_number,:line_number,"Sale Row", {:data_type=>:integer}],
      [3,:soln_ordered_qty,:quantity,"Sale Quantity",{:data_type=>:decimal}],
      [4,:soln_ppu,:price_per_unit,"Price / Unit",{:data_type => :decimal}]
    ]
    add_fields CoreModule::SALE_LINE, make_product_arrays(100,"soln","sales_order_lines")
  end
end; end; end
