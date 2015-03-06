module OpenChain; module ModelFieldDefinition; module ContainerFieldDefinition
  def add_container_fields
    add_fields CoreModule::CONTAINER, [
      [1,:con_uid,:id,"Unique ID",{data_type: :string}],
      [2,:con_container_number,:container_number,"Container Number",{data_type: :string}],
      [3,:con_container_size,:container_size,"Size",{data_type: :string}],
      [4,:con_size_description,:size_description,"Size Description",{data_type: :string}],
      [5,:con_weight,:weight,"Weight",{data_type: :string}],
      [6,:con_seal_number,:seal_number,"Seal Number",{data_type: :string}],
      [7,:con_teus,:teus,"TEUs",{data_type: :integer}],
      [8,:con_fcl_lcl,:fcl_lcl,"Full Container",{data_type: :string}],
      [9,:con_quantity,:quantity,"AMS Qauntity",{data_type: :integer}],
      [10,:con_uom,:uom,"AMS UOM",{data_type: :string}],
      [11,:con_shipment_line_count,:shipment_line_count,"Shipment Line Count",{data_type: :integer,
        import_lambda: lambda {|con,data| return "Shipment line count cannot be set by import."},
        export_lambda: lambda {|con| con.shipment_lines.size},
        qualified_field_name: "(SELECT count(*) FROM shipment_lines WHERE shipment_lines.container_id = containers.id)",
        history_ignore: true,
        read_only: true
      }]
    ]
  end
end; end; end
