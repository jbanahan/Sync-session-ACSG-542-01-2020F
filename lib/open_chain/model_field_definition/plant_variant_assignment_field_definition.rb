module OpenChain; module ModelFieldDefinition; module PlantVariantAssignmentFieldDefinition
  def add_plant_variant_assignment_fields
    add_fields CoreModule::PLANT_VARIANT_ASSIGNMENT, [
      [1, :pva_assignment_id, :id, "Assignment ID", {
        data_type: :integer,
        history_ignore: true,
        read_only: true
      }],
      [2, :pva_plant_name, :plant_name, "Plant Name", {
        data_type: :string,
        read_only: true,
        export_lambda: lambda {|obj| obj.plant ? ModelField.find_by_uid(:plant_name).process_export(obj.plant, nil, true) : ''},
        qualified_field_name: "(SELECT name FROM plants WHERE plants.id = plant_variant_assignments.plant_id)"
      }],
      [3, :pva_company_name, :company_name, "Company Name", {
        data_type: :string,
        read_only: true,
        export_lambda: lambda {|obj| (obj.plant && obj.plant.company) ? ModelField.find_by_uid(:cmp_name).process_export(obj.plant.company, nil, true) : ''},
        qualified_field_name: "(SELECT companies.name FROM plants INNER JOIN companies ON companies.id = plants.company_id WHERE plants.id = plant_variant_assignments.plant_id)"
      }],
      [4, :pva_var_identifier, :var_identifier, "Variant Identifier", {
        data_type: :string,
        read_only: true,
        export_lambda: lambda {|obj| (obj.variant) ? ModelField.find_by_uid(:var_identifier).process_export(obj.variant, nil, true) : ''},
        qualified_field_name: "(SELECT variant_identifier FROM variants WHERE variants.id = plant_variant_assignments.variant_id)"
      }],
      [5, :pva_prod_uid, :prod_uid, "Product UID", {
        data_type: :string,
        read_only: true,
        export_lambda: lambda {|obj| (obj.variant && obj.variant.product) ? ModelField.find_by_uid(:prod_uid).process_export(obj.variant.product, nil, true) : ''},
        qualified_field_name: "(SELECT products.unique_identifier FROM variants INNER JOIN products ON variants.product_id = products.id WHERE variants.id = plant_variant_assignments.variant_id)"
      }],
      [5, :pva_prod_name, :prod_name, "Product Name", {
        data_type: :string,
        read_only: true,
        export_lambda: lambda {|obj| (obj.variant && obj.variant.product) ? ModelField.find_by_uid(:prod_name).process_export(obj.variant.product, nil, true) : ''},
        qualified_field_name: "(SELECT products.name FROM variants INNER JOIN products ON variants.product_id = products.id WHERE variants.id = plant_variant_assignments.variant_id)"
      }],
      [6, :pva_company_id, :company_id, "Company ID", {
        data_type: :integer,
        read_only: true,
        export_lambda: lambda {|obj| obj.plant ? obj.plant.company_id : ''},
        qualified_field_name: "(SELECT plants.company_id FROM plants WHERE plants.id = plant_variant_assignments.plant_id)"
      }]
    ]
  end
end; end; end
