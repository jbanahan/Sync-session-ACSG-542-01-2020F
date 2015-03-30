module OpenChain; module ModelFieldDefinition; module PlantFieldDefinition
  def add_plant_fields
    add_fields CoreModule::PLANT, [
      [1,:plant_name,:name,"Name",{data_type: :string}]
    ]
    add_fields CoreModule::PLANT, make_attachment_arrays(100,'plant',CoreModule::PLANT)
  end
end; end; end
