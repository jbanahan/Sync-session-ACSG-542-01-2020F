module OpenChain; module ModelFieldDefinition; module PlantFieldDefinition
  def add_plant_fields
    add_fields CoreModule::PLANT, [
      [1,:plant_name,:name,"Name",{data_type: :string}]
    ]
  end
end; end; end
