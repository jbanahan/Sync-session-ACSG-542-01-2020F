module OpenChain; module ModelFieldDefinition; module OrderLineFieldDefinition
  def add_order_line_fields
    add_fields CoreModule::ORDER_LINE, [
      [1, :ordln_line_number, :line_number, "Order Line", {:data_type=>:integer}],
      [3, :ordln_ordered_qty, :quantity, "Order Quantity", {:data_type=>:decimal}],
      [4, :ordln_ppu, :price_per_unit, "Price / Unit", {:data_type=>:decimal}],
      [5, :ordln_ms_state, :state, "Milestone State", {:data_type=>:string,
        :import_lambda => lambda {|obj, data| return "Milestone State was ignored. (read only)"},
        :export_lambda => lambda {|obj| obj.worst_milestone_state },
        :qualified_field_name => "(SELECT IFNULL(milestone_forecast_sets.state,'') as ms_state FROM milestone_forecast_sets INNER JOIN piece_sets on piece_sets.id = milestone_forecast_sets.piece_set_id WHERE piece_sets.order_line_id = order_lines.id ORDER BY FIELD(milestone_forecast_sets.state,'Achieved','Pending','Unplanned','Missed','Trouble','Overdue') DESC LIMIT 1)"
      }],
      [6, :ordln_currency, :currency, "Currency", {data_type: :string}],
      [7, :ordln_country_of_origin, :country_of_origin, "Country of Origin", {data_type: :string}],
      [8, :ordln_hts, :hts, "HTS Code", {data_type: :string,
        export_lambda: lambda {|obj| obj.hts.blank? ? '' : obj.hts.hts_format },
        import_lambda: lambda do |obj, data|
          obj.hts = (data.blank? ? nil : data.to_s.gsub(".", ""))
          obj.hts.present? ? "HTS Code set to #{obj.hts}." : "HTS Code cleared."
        end,
        search_value_preprocess_lambda: hts_search_value_preprocess_lambda()
      }],
      [9, :ordln_sku, :sku, 'SKU', {data_type: :string}],
      [10, :ordln_total_cost, :total_cost, "Total Price", {data_type: :decimal, read_only: true,
        qualified_field_name: OrderLine::TOTAL_COST_SUBQUERY
      }],
      [11, :ordln_unit_of_measure, :unit_of_measure, 'Unit of Measure', {data_type: :string}],
      [12, :ordln_has_variants, :has_variants, "Has Variants", {
        data_type: :boolean,
        read_only: true,
        history_ignore: true,
        export_lambda: lambda {|ol|
          ol.product && !ol.product.variants.empty?
        },
        qualified_field_name: "(SELECT IF((SELECT count(*) FROM products INNER JOIN variants ON variants.product_id = products.id where order_lines.product_id = products.id)>0,1,null))"
      }],
      [13, :ordln_msrp, :unit_msrp, "MSRP / Unit", {data_type: :decimal} ]
    ]
    add_fields CoreModule::ORDER_LINE, make_product_arrays(100, "ordln", "order_lines")
    add_fields CoreModule::ORDER_LINE, make_ship_to_arrays(200, "ordln", "order_lines")
    add_fields CoreModule::ORDER_LINE, make_variant_arrays(300, "ordln", "order_lines")

    pva_fields_to_add = []
    pva_index = 300
    CustomDefinition.where(module_type:'ProductVendorAssignment').each_with_index do |cd, i|
      # Virtual fields won't work as nested searches at the moment...not entirely sure how we can make them work, so I'm skipping them for now
      next if cd.virtual_field?

      pva_fields_to_add << [
        pva_index+i,
        "#{cd.model_field_uid}_order_lines".to_sym,
        "#{cd.model_field_uid}_order_lines".to_sym,
        "Product Vendor Assignment - #{cd.label.to_s}", {
          data_type: cd.data_type,
          read_only: true,
          qualified_field_name: "(SELECT #{cd.data_column} FROM product_vendor_assignments INNER JOIN custom_values ON custom_values.custom_definition_id = #{cd.id} AND custom_values.customizable_id = product_vendor_assignments.id and custom_values.customizable_type = 'ProductVendorAssignment' WHERE product_vendor_assignments.product_id = order_lines.product_id AND product_vendor_assignments.vendor_id = (SELECT vendor_id FROM orders WHERE orders.id = order_lines.order_id) LIMIT 1)",
          export_lambda: lambda {|ol| pva = ProductVendorAssignment.where(product_id:ol.product_id, vendor_id:ol.order.vendor_id).first; pva ? pva.get_custom_value(cd).value : nil},
          field_validator_rule: ModelField.field_validator_rule(cd.model_field_uid)
        }
      ]
      add_fields CoreModule::ORDER_LINE, pva_fields_to_add
    end
    add_model_fields CoreModule::ORDER_LINE, make_country_hts_fields(CoreModule::ORDER_LINE, product_lambda: -> (obj) { obj.product } )

  end
end; end; end
