module OpenChain; module ModelFieldDefinition; module CartonSetFieldDefinition
  def add_carton_set_fields
    add_fields CoreModule::CARTON_SET, [
      [1,:cs_starting_carton,:starting_carton,"Starting Carton",{data_type: :integer}],
      [2,:cs_carton_qty,:carton_qty,"Carton Count",{data_type: :integer}],
      [3,:cs_length,:length_cm,"Length (cm)", {data_type: :decimal}],
      [4,:cs_width,:width_cm,"Width (cm)", {data_type: :decimal}],
      [5,:cs_height,:height_cm,"Height (cm)", {data_type: :decimal}],
      [6,:cs_net_net,:net_net_kgs,"Net Net Weight (kgs)", {data_type: :decimal}],
      [7,:cs_net,:net_kgs,"Net Weight (kgs)", {data_type: :decimal}],
      [8,:cs_gross,:gross_kgs,"Gross Weight (kgs)", {data_type: :decimal}]
    ]
  end
end; end; end
