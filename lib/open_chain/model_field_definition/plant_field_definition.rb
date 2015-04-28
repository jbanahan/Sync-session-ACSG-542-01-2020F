module OpenChain; module ModelFieldDefinition; module PlantFieldDefinition
  def add_plant_fields
    add_fields CoreModule::PLANT, [
      [1,:plant_name,:name,"Name",{data_type: :string}],
      [2,:plant_product_group_names,:product_group_names,"Product Group Names",{
        data_type: :text,
        read_only: true,
        import_lambda: lambda {|obj,val| "Product Group Names is read only."},
        export_lambda: lambda {|obj| obj.product_groups.collect {|pg| pg.name}.compact.uniq.sort.join("\n")},
        qualified_field_name: "(SELECT GROUP_CONCAT(DISTINCT pg.name ORDER BY pg.name SEPARATOR '\n ') 
          FROM plant_product_group_assignments ppga
          INNER JOIN product_groups pg ON pg.id = ppga.product_group_id
          WHERE ppga.plant_id = plants.id)"
      }]
    ]
    add_fields CoreModule::PLANT, make_attachment_arrays(100,'plant',CoreModule::PLANT)
  end
end; end; end
