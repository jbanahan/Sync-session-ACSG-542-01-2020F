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
    ]
    add_fields CoreModule::SHIPMENT, make_vendor_arrays(100,"shp","shipments")
    add_fields CoreModule::SHIPMENT, make_ship_to_arrays(200,"shp","shipments")
    add_fields CoreModule::SHIPMENT, make_ship_from_arrays(250,"shp","shipments")
    add_fields CoreModule::SHIPMENT, make_carrier_arrays(300,"shp","shipments")
    add_fields CoreModule::SHIPMENT, make_master_setup_array(400,"shp")
    add_fields CoreModule::SHIPMENT, make_importer_arrays(500,"shp","shipments")
    add_fields CoreModule::SHIPMENT, make_comment_arrays(600,'shp','Shipment')
    add_fields CoreModule::SHIPMENT, make_port_arrays(700,'shp_dest_port','shipments','destination_port','Destination Port')
  end
end; end; end
