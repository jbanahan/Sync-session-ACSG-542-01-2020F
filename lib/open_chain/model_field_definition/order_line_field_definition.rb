module OpenChain; module ModelFieldDefinition; module OrderLineFieldDefinition
  def add_order_line_fields
    add_fields CoreModule::ORDER_LINE, [
      [1,:ordln_line_number,:line_number,"Order Line",{:data_type=>:integer}],
      [3,:ordln_ordered_qty,:quantity,"Order Quantity",{:data_type=>:decimal}],
      [4,:ordln_ppu,:price_per_unit,"Price / Unit",{:data_type=>:decimal}],
      [5,:ordln_ms_state,:state,"Milestone State",{:data_type=>:string,
        :import_lambda => lambda {|obj,data| return "Milestone State was ignored. (read only)"},
        :export_lambda => lambda {|obj| obj.worst_milestone_state },
        :qualified_field_name => "(SELECT IFNULL(milestone_forecast_sets.state,'') as ms_state FROM milestone_forecast_sets INNER JOIN piece_sets on piece_sets.id = milestone_forecast_sets.piece_set_id WHERE piece_sets.order_line_id = order_lines.id ORDER BY FIELD(milestone_forecast_sets.state,'Achieved','Pending','Unplanned','Missed','Trouble','Overdue') DESC LIMIT 1)"
      }],
      [6,:ordln_currency,:currency,"Currency",{data_type: :string}],
      [7,:ordln_country_of_origin,:country_of_origin,"Country of Origin",{data_type: :string}],
      [8,:ordln_hts,:hts,"HTS Code",{data_type: :string,
        :export_lambda=> lambda{|obj| obj.hts.blank? ? '' : obj.hts.hts_format}
      }],
      [9,:ordln_sku,:sku,'SKU',{data_type: :string}],
      [10,:ordln_total_cost, :total_cost, "Total Price", {data_type: :decimal, read_only: true,
        qualified_field_name: "IFNULL((order_lines.price_per_unit * order_lines.quantity), 0)"
      }]
    ]
    add_fields CoreModule::ORDER_LINE, make_product_arrays(100,"ordln","order_lines")
  end
end; end; end
