module OpenChain; module ModelFieldDefinition; module DeliveryFieldDefinition
  def add_delivery_fields
    add_fields CoreModule::DELIVERY, [
      [1,:del_ref,:reference,"Reference",{:data_type=>:string}],
      [2,:del_mode,:mode,"Mode",{:data_type=>:string}],
    ]
    add_fields CoreModule::DELIVERY, make_ship_from_arrays(100,"del","deliveries")
    add_fields CoreModule::DELIVERY, make_ship_to_arrays(200,"del","deliveries")
    add_fields CoreModule::DELIVERY, make_carrier_arrays(300,"del","deliveries")
    add_fields CoreModule::DELIVERY, make_customer_arrays(400,"del","deliveries")
    add_fields CoreModule::DELIVERY, make_master_setup_array(500,"del")
  end
end; end; end
