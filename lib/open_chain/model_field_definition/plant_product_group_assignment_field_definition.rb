module OpenChain; module ModelFieldDefinition; module PlantProductGroupAssignmentFieldDefinition
  def add_plant_product_group_assignment_fields
    add_fields CoreModule::PLANT_PRODUCT_GROUP_ASSIGNMENT, [
      [1,:ppga_pg_name,:name,"Product Group Name",{
        data_type: :string,
        read_only: true,
        export_lambda: lambda {|ppga| ppga.product_group.blank? ? '' : ppga.product_group.name},
        qualified_field_name: '(SELECT name FROM product_groups WHERE product_groups.id = plant_product_group_assignments.product_group_id)'
      }],
      [2,:ppga_plant_name,:name,"Plant Name",{
        data_type: :string,
        read_only: true,
        export_lambda: lambda {|ppga| ppga.plant.blank? ? '' : ppga.plant.name},
        qualified_field_name: '(SELECT name FROM plants WHERE plants.id = plant_product_group_assignments.plant_id)'
      }],
      [3,:vendor_name,:name,"Vendor Name",{
        data_type: :string,
        read_only: true,
        export_lambda: lambda { |ppga|
          return '' if ppga.plant.blank?
          return '' if ppga.plant.company.blank?
          return ppga.plant.company.name
        },
        qualified_field_name: '(SELECT companies.name from plants INNER JOIN companies ON companies.id = plants.company_id WHERE plants.id = plant_product_group_assignments.plant_id)'
      }]
    ]
    add_fields CoreModule::PLANT_PRODUCT_GROUP_ASSIGNMENT, make_attachment_arrays(100,'ppga',CoreModule::PLANT_PRODUCT_GROUP_ASSIGNMENT)
  end
end; end; end
