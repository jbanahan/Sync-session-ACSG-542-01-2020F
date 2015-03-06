module OpenChain; module ModelFieldDefinition; module ShipmentLineFieldDefinition
  def add_shipment_line_fields
    add_fields CoreModule::SHIPMENT_LINE, [
      [1,:shpln_line_number,:line_number,"Shipment Row",{:data_type=>:integer}],
      [2,:shpln_shipped_qty,:quantity,"Quantity Shipped",{:data_type=>:decimal}],
      [3,:shpln_container_number,:container_number,"Container Number",{data_type: :string,
        export_lambda: lambda {|sl| sl.container ? sl.container.container_number : ''},
        import_lambda: lambda {|o,d| "Container Number cannot be set via import."},
        qualified_field_name: "(SELECT container_number FROM containers WHERE containers.id = shipment_lines.container_id)"
        },
        read_only:true],
      [4,:shpln_container_size,:container_size,"Container Size",{data_type: :string,
        export_lambda: lambda {|sl| sl.container ? sl.container.container_size : ''},
        import_lambda: lambda {|o,d| "Container Size cannot be set via import."},
        qualified_field_name: "(SELECT container_size FROM containers WHERE containers.id = shipment_lines.container_id)",
        history_ignore: true,
        read_only:true
        }],
      [5,:shpln_container_uid,:container_id,"Container Unique ID",{data_type: :integer,
        import_lambda: lambda {|sl,id|
          if id.blank?
            sl.container_id = nil
            return "Container removed from line."
          end
          con = sl.shipment.containers.to_a.find {|c| c.id == id}
          return "Container with ID #{id} not found. Ignored." unless con
          return "#{ModelField.find_by_uid(:shpln_container_uid).label(false)} is not part of this shipment and was ignored." unless con.shipment_id == sl.shipment_id
          sl.container_id = con.id
          "#{ModelField.find_by_uid(:shpln_container_uid).label(false)} set to #{con.id}."
        },
        history_ignore:true
        }],
      [6,:shpln_cbms,:cbms,"Volume (CBMS)",{data_type: :decimal}],
      [7,:shpln_gross_kgs,:gross_kgs,"Gross Weight (KGS)",{data_type: :decimal}],
      [8,:shpln_carton_qty,:carton_qty,"Cartons",{data_type: :integer}],
      [9,:shpln_vendors,:vendor_name,"Vendor(s)",{data_type: :text,
        read_only: true,
        export_lambda: lambda {|sl| sl.order_lines.collect {|ol| ol.order.vendor ? ol.order.vendor.name : nil}.uniq.compact.sort.join(',') },
        import_lambda: lambda {|o,d| "Linked fields are read only."},
        qualified_field_name: "(SELECT GROUP_CONCAT(DISTINCT companies.name ORDER BY name SEPARATOR ',') FROM piece_sets INNER JOIN order_lines on order_lines.id = piece_sets.order_line_id INNER JOIN orders ON orders.id = order_lines.order_id INNER JOIN companies ON companies.id = orders.vendor_id WHERE shipment_lines.id = piece_sets.shipment_line_id)",
        history_ignore:true
        }],
      [10,:shpln_po_value,:po_value,"Shipped PO Value",{
        data_type: :currency,
        read_only: true,
        export_lambda: lambda {|sl| sl.order_lines.inject(BigDecimal('0.00')) {|i,ol|
          ppu = ol.price_per_unit.blank? ? 0 : ol.price_per_unit
          qty = sl.quantity.blank? ? 0 : sl.quantity
          i + (ppu*qty)}},
        import_lambda: lambda {|o,d| "Linked fields are read only."},
        qualified_field_name: "(SELECT SUM(order_lines.price_per_unit * shipment_lines.quantity) FROM piece_sets INNER JOIN order_lines on order_lines.id = piece_sets.order_line_id WHERE piece_sets.shipment_line_id = shipment_lines.id)",
        history_ignore:true,
        read_only:true
        }],
      [11,:shpln_cust_ord_no,:customer_order_number,"Order(s)",{data_type: :text,
        read_only: true,
        export_lambda: lambda {|sl| sl.order_lines.collect {|ol| ol.order.customer_order_number}.uniq.compact.sort.join(',') },
        import_lambda: lambda {|o,d| "Linked fields are read only."},
        qualified_field_name: "(SELECT GROUP_CONCAT(DISTINCT orders.customer_order_number ORDER BY orders.customer_order_number SEPARATOR ',') FROM piece_sets INNER JOIN order_lines on order_lines.id = piece_sets.order_line_id INNER JOIN orders ON orders.id = order_lines.order_id WHERE shipment_lines.id = piece_sets.shipment_line_id)",
        history_ignore:true,
        read_only:true
        }],
      [12,:shpln_carton_set_uid,:carton_set_id,"Carton Set Unique ID",{data_type: :integer,
        import_lambda: lambda {|sl,id|
          return "#{ModelField.find_by_uid(:shpln_carton_set_uid).label} was blank." if id.blank?
          cs = CartonSet.find_by_id id
          return "Carton Set with ID #{id} not found. Ignored." unless cs
          return "#{ModelField.find_by_uid(:shpln_carton_set_uid).label} is not part of this shipment and was ignored." unless cs.shipment_id == sl.shipment_id
          sl.carton_set_id = cs.id
          "#{ModelField.find_by_uid(:shpln_carton_set_uid).label} set to #{cs.id}."
        }
        }]
    ]
    add_fields CoreModule::SHIPMENT_LINE, make_product_arrays(100,"shpln","shipment_lines")
  end
end; end; end
