module OpenChain; module ModelFieldDefinition; module ShipmentFieldDefinition
  def add_shipment_fields
    add_fields CoreModule::SHIPMENT, [
      [1,:shp_ref,:reference,"Reference Number",{:data_type=>:string}],
      [2,:shp_mode,:mode,"Mode",{:data_type=>:string}],
      [3,:shp_master_bill_of_lading,:master_bill_of_lading,"Master Bill of Lading",{:data_type=>:string}],
      [4,:shp_house_bill_of_lading,:house_bill_of_lading,"House Bill of Lading",{:data_type=>:string}],
      [5,:shp_booking_number,:booking_number,"Booking Number",{:data_type=>:string}],
      [6,:shp_receipt_location,:receipt_location,"Freight Receipt Location",{:data_type=>:string}],
      [11,:shp_freight_terms,:freight_terms,"Freight Terms",{:data_type=>:string}],
      [12,:shp_lcl,:lcl,"LCL",{:data_type=>:boolean}],
      [13,:shp_shipment_type,:shipment_type,"Shipment Type",{:data_type=>:string}],
      [14,:shp_booking_shipment_type,:booking_shipment_type,"Shipment Type - Booked",{:data_type=>:string}]       ,
      [15,:shp_booking_mode,:booking_mode,"Mode - Booked",{:data_type=>:string}],
      [16,:shp_vessel,:vessel,"Vessel",{:data_type=>:string}],
      [17,:shp_voyage,:voyage,"Voyage",{:data_type=>:string}],
      [18,:shp_vessel_carrier_scac,:vessel_carrier_scac,"Vessel SCAC",{:data_type=>:string}],
      [19,:shp_booking_received_date,:booking_received_date,"Booking Received Date",{:data_type=>:date,:read_only=>true}],
      [20,:shp_booking_confirmed_date,:booking_confirmed_date,"Booking Confirmed Date",{:data_type=>:date}],
      [21,:shp_booking_cutoff_date,:booking_cutoff_date,"Cutoff Date",{:data_type=>:date}],
      [22,:shp_booking_est_arrival_date,:booking_est_arrival_date,"Est Arrival Date - Booked",{:data_type=>:date}],
      [23,:shp_booking_est_departure_date,:booking_est_departure_date,"Est Departure Date - Booked",{:data_type=>:date}],
      [24,:shp_docs_received_date,:docs_received_date,"Docs Received Date",{:data_type=>:date}],
      [25,:shp_cargo_on_hand_date,:cargo_on_hand_date,"Cargo On Hand Date",{:data_type=>:date}],
      [26,:shp_est_departure_date,:est_departure_date,"Est Departure Date",{:data_type=>:date}],
      [27,:shp_departure_date,:departure_date,"Departure Date",{:data_type=>:date}],
      [28,:shp_est_arrival_port_date,:est_arrival_port_date,"Est Arrival Date",{:data_type=>:date}],
      [29,:shp_arrival_port_date,:arrival_port_date,"Arrival Date",{:data_type=>:date}],
      [30,:shp_est_delivery_date,:est_delivery_date,"Est Delivery Date",{:data_type=>:date}],
      [31,:shp_delivered_date,:delivered_date,"Delivered Date",{:data_type=>:date}],
      [32,:shp_importer_reference,:importer_reference,"Importer Reference",{data_type: :string}],
      [33,:shp_cargo_ready_date,:cargo_ready_date,'Cargo Ready Date',{data_type: :date}],
      [34,:shp_booking_requested_by_full_name,:username,"Booking Requested By", {
        :import_lambda => lambda {|a,b| return "Booking Requested By cannot be set by import, ignored."},
        :export_lambda => lambda {|obj|
          u = obj.booking_requested_by
          u.blank? ? "" : u.full_name
        },
        :qualified_field_name => "(SELECT CONCAT_WS(' ', IFNULL(first_name, ''), IFNULL(last_name, '')) FROM users where users.id = shipments.booking_requested_by_id)",
        :data_type=>:string
      }],
      [35,:shp_booking_confirmed_by_full_name,:username,"Booking Confirmed By", {
        :import_lambda => lambda {|a,b| return "Booking Confirmed By cannot be set by import, ignored."},
        :export_lambda => lambda {|obj|
          u = obj.booking_confirmed_by
          u.blank? ? "" : u.full_name
        },
        :qualified_field_name => "(SELECT CONCAT_WS(' ', IFNULL(first_name, ''), IFNULL(last_name, '')) FROM users where users.id = shipments.booking_confirmed_by_id)",
        :data_type=>:string
      }],
      [36,:shp_booking_approved_by_full_name,:username,"Booking Approved By", {
        :import_lambda => lambda {|a,b| return "Booking Approved By cannot be set by import, ignored."},
        :export_lambda => lambda {|obj|
          u = obj.booking_approved_by
          u.blank? ? "" : u.full_name
        },
        :qualified_field_name => "(SELECT CONCAT_WS(' ', IFNULL(first_name, ''), IFNULL(last_name, '')) FROM users where users.id = shipments.booking_approved_by_id)",
        :data_type=>:string
      }],
      [37,:shp_booking_approved_date,:booking_approved_date,"Booking Approved Date",{data_type: 'date', read_only: true}],
      [38,:shp_booked_quantity,:booked_quantity,"Booked Quantity",{data_type: :decimal, read_only:true}],
      [39,:shp_canceled_by_full_name,:username,"Canceled By", {
        :import_lambda => lambda {|a,b| return "Canceled By cannot be set by import, ignored."},
        :export_lambda => lambda {|obj|
          u = obj.canceled_by
          u.blank? ? "" : u.full_name
        },
        :qualified_field_name => "(SELECT CONCAT_WS(' ', IFNULL(first_name, ''), IFNULL(last_name, '')) FROM users where users.id = shipments.canceled_by_id)",
        :data_type=>:string
      }],
      [40,:shp_canceled_date,:canceled_date,"Canceled Date",{data_type: 'date', read_only: true}],
      [41,:shp_total_cartons,:total_cartons,"Total Cartons",{
        data_type: :integer,
        read_only: true,
        import_lambda: lambda {|a,b| return "Total cartons is read only."},
        export_lambda: lambda {|obj| obj.carton_sets.inject(0) { |tot, cs| tot + (cs.carton_qty.nil? ? 0 : cs.carton_qty) }},
        qualified_field_name: "(SELECT SUM(carton_qty) FROM carton_sets WHERE carton_sets.shipment_id = shipments.id)"
      }],
      [42,:shp_vessel_nationality, :vessel_nationality, 'Nationality of Ship', {data_type: :string}],
      [43,:shp_marks_and_numbers, :marks_and_numbers, 'Marks & Numbers', {data_type: :string}],
      [44,:shp_number_of_packages, :number_of_packages, 'Number of Packages', {data_type: :integer}],
      [45,:shp_number_of_packages_uom, :number_of_packages_uom, 'Number of Packages UOM', {data_type: :string}],
      [46, :shp_gross_weight, :gross_weight, 'Gross Weight (KGs)', {data_type: :decimal}],
      [47,:shp_booked_orders,:booked_orders,"Booked Orders",{
            data_type: :text,
            read_only: true,
            import_lambda: lambda {|obj,val| "Booked Orders is read only."},
            export_lambda: lambda {|obj| obj.booking_lines.flat_map(&:customer_order_number).compact.uniq.sort.join("\n ")},
            qualified_field_name: "(SELECT GROUP_CONCAT(DISTINCT orders.order_number ORDER BY orders.order_number SEPARATOR '\n ')
          FROM booking_lines
          INNER JOIN order_lines ON booking_lines.order_line_id = order_lines.id
          INNER JOIN orders ON orders.id = order_lines.order_id OR orders.id = booking_lines.order_id
          WHERE booking_lines.shipment_id = shipments.id)"
        }],
      [48,:shp_shipped_orders,:shipped_orders,"Shipped Orders",{
             data_type: :text,
             read_only: true,
             import_lambda: lambda {|obj,val| "Shipped Orders is read only."},
             export_lambda: lambda {|obj| obj.shipment_lines.flat_map(&:order_lines).map(&:order).map(&:order_number).compact.uniq.sort.join("\n ")},
             qualified_field_name: "(SELECT GROUP_CONCAT(DISTINCT orders.order_number ORDER BY orders.order_number SEPARATOR '\n ')
          FROM shipment_lines
          INNER JOIN piece_sets ON piece_sets.shipment_line_id = shipment_lines.id
          INNER JOIN order_lines ON piece_sets.order_line_id = order_lines.id
          INNER JOIN orders ON orders.id = order_lines.order_id
          WHERE shipment_lines.shipment_id = shipments.id)"
         }],
      [49,:shp_shipped_products,:shipped_products,"Shipped Products",{
             data_type: :text,
             read_only: true,
             import_lambda: lambda {|obj,val| "Shipped Products is read only."},
             export_lambda: lambda {|obj| obj.shipment_lines.flat_map(&:order_lines).map(&:product).map(&:unique_identifier).compact.uniq.sort.join("\n ")},
             qualified_field_name: "(SELECT GROUP_CONCAT(DISTINCT products.unique_identifier ORDER BY products.unique_identifier SEPARATOR '\n ')
          FROM shipment_lines
          INNER JOIN products ON products.id = shipment_lines.product_id
          WHERE shipment_lines.shipment_id = shipments.id)"
         }],
      [50,:shp_booked_products,:booked_products,"Booked Products",{
             data_type: :text,
             read_only: true,
             import_lambda: lambda {|obj,val| "Booked Products is read only."},
             export_lambda: lambda {|obj| obj.booking_lines.map(&:product_identifier).compact.uniq.sort.join("\n ")},
             qualified_field_name: "(SELECT GROUP_CONCAT(DISTINCT products.unique_identifier ORDER BY products.unique_identifier SEPARATOR '\n ')
          FROM booking_lines
          INNER JOIN order_lines ON order_lines.id = booking_lines.order_line_id
          INNER JOIN products ON products.id = booking_lines.product_id OR products.id = order_lines.product_id
          WHERE booking_lines.shipment_id = shipments.id)"
         }],
      [51, :shp_booking_carrier, :booking_carrier, "Booking Carrier", {data_type: :string}],
      [52, :shp_booking_vessel, :booking_vessel, "Booking Vessel", {data_type: :string}],
      [53, :shp_delay_reason_codes, :delay_reason_codes, "Delay Reason", {data_type: :string}],
      [54, :shp_cutoff_date, :shipment_cutoff_date, "Shipment Cutoff Date", {data_type: :date}],
      [55, :shp_fish_and_wildlife, :fish_and_wildlife, "Fish And Wildlife", {data_type: :boolean}],
      [56, :shp_volume, :volume, "Volume", {data_type: :decimal}],
      [57, :shp_dimensional_weight, :dimensional_weight, "Dimensional Weight", {
             data_type: :decimal,
             read_only: true,
             export_lambda: lambda {|obj| obj.dimensional_weight },
             qualified_field_name: "(SELECT IFNULL(shipments.volume,0) / 0.006)"
         }],
      [58, :shp_chargeable_weight, :chargeable_weight, "Chargeable Weight", {
             data_type: :boolean,
             read_only: true,
             export_lambda: lambda { |obj| obj.chargeable_weight },
             qualified_field_name: "(SELECT CASE WHEN IFNULL(shipments.gross_weight,0) > (IFNULL(shipments.volume,0) / 0.006) THEN IFNULL(shipments.gross_weight,0) ELSE (IFNULL(shipments.volume,0) / 0.006) END)"
         }],
      [59,:shp_cancel_requested_by_full_name,:username,"Cancel Requested By", {
             :import_lambda => lambda {|a,b| return "Cancel Requested By cannot be set by import, ignored."},
             :export_lambda => lambda {|obj|
               u = obj.cancel_requested_by
               u.blank? ? "" : u.full_name
             },
             :qualified_field_name => "(SELECT CONCAT_WS(' ', IFNULL(first_name, ''), IFNULL(last_name, '')) FROM users where users.id = shipments.cancel_requested_by_id)",
             :data_type=>:string
         }],
      [60,:shp_cancel_requested_at,:cancel_requested_at,"Cancel Requested At",{data_type: :datetime, read_only: true}],
      # [61,:shp_manufacturer_address_id, :manufacturer_address_id, "Manufacturer Address Id",{data_type: :integer}],
      # [62,:shp_manufacturer_address_name, :manufacturer_address_name, "Manufacturer Address Name",{
      #        data_type: :string,
      #        read_only:true,
      #        export_lambda: lambda{|obj| obj.manufacturer_address.try(:name) },
      #        qualified_field_name: "(SELECT name FROM addresses WHERE addresses.id = shipments.manufacturer_address_id)"
      #    }],
      # [63, :shp_manufacturer_full_address, :manufacturer_address, "Manufacturer Address", {
      #        data_type: :string,
      #        read_only:true,
      #        export_lambda: lambda {|obj| obj.manufacturer_address.try(:full_address)},
      #        qualified_field_name: "(SELECT CONCAT_WS(' ', IFNULL(line_1, ''), IFNULL(line_2, ''), IFNULL(line_3, ''), IFNULL(city, ''), IFNULL(state, ''), IFNULL(postal_code, '')) FROM addresses where addresses.id = shipments.manufacturer_address_id)"
      #    }],
      # [64,:shp_buyer_address_id, :buyer_address_id, "Buyer Address Id",{data_type: :integer}],
      # [62,:shp_buyer_address_name, :buyer_address_name, "Buyer Address Name",{
      #        data_type: :string,
      #        read_only:true,
      #        export_lambda: lambda{|obj| obj.manufacturer_address.try(:name) },
      #        qualified_field_name: "(SELECT name FROM addresses WHERE addresses.id = shipments.buyer_address_id)"
      #    }],
      # [66, :shp_buyer_full_address, :buyer_address, "Buyer Address", {
      #        data_type: :string,
      #        read_only:true,
      #        export_lambda: lambda {|obj| obj.buyer_address.try(:full_address)},
      #        qualified_field_name: "(SELECT CONCAT_WS(' ', IFNULL(line_1, ''), IFNULL(line_2, ''), IFNULL(line_3, ''), IFNULL(city, ''), IFNULL(state, ''), IFNULL(postal_code, '')) FROM addresses where addresses.id = shipments.buyer_address_id)"
      #    }],
    ]
    add_fields CoreModule::SHIPMENT, make_vendor_arrays(100,"shp","shipments")
    add_fields CoreModule::SHIPMENT, make_ship_to_arrays(200,"shp","shipments")
    add_fields CoreModule::SHIPMENT, make_ship_from_arrays(250,"shp","shipments")
    add_fields CoreModule::SHIPMENT, make_carrier_arrays(300,"shp","shipments")
    add_fields CoreModule::SHIPMENT, make_master_setup_array(400,"shp")
    add_fields CoreModule::SHIPMENT, make_importer_arrays(500,"shp","shipments")
    add_fields CoreModule::SHIPMENT, make_comment_arrays(600,'shp','Shipment')
    add_fields CoreModule::SHIPMENT, make_port_arrays(700,'shp_dest_port','shipments','destination_port','Destination Port')
    add_fields CoreModule::SHIPMENT, make_port_arrays(800, 'shp_first_port_receipt','shipments','first_port_receipt','First Port of Receipt')
    add_fields CoreModule::SHIPMENT, make_port_arrays(900, 'shp_lading_port','shipments','lading_port','Foreign Port of Lading')
    add_fields CoreModule::SHIPMENT, make_port_arrays(1000, 'shp_last_foreign_port','shipments','last_foreign_port','Last Foreign Port')
    add_fields CoreModule::SHIPMENT, make_port_arrays(1100, 'shp_unlading_port','shipments','unlading_port','First US Port')
    add_fields CoreModule::SHIPMENT, make_address_arrays(1200,'shp','shipments','manufacturer')
    add_fields CoreModule::SHIPMENT, make_address_arrays(1205,'shp','shipments','buyer')
    add_fields CoreModule::SHIPMENT, make_address_arrays(1210,'shp','shipments','seller')
    add_fields CoreModule::SHIPMENT, make_address_arrays(1215,'shp','shipments','ship_to')
    add_fields CoreModule::SHIPMENT, make_address_arrays(1220,'shp','shipments','container_stuffing')
    add_fields CoreModule::SHIPMENT, make_address_arrays(1225,'shp','shipments','consolidator')

  end
end; end; end
