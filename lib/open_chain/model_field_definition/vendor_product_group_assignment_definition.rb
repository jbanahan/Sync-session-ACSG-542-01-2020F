module OpenChain; module ModelFieldDefinition; module VendorProductGroupAssignmentDefinition
  def add_vendor_product_group_assignment_fields
    add_fields CoreModule::VENDOR_PRODUCT_GROUP_ASSIGNMENT, [
      [1,:vpga_product_group_name,:name,"Product Group",{data_type: :string,
        export_lambda: lambda {|obj| obj.product_group ? obj.product_group.name : ""},
        read_only: true,
        qualified_field_name: '(select name from product_groups where product_groups.id = vendor_product_group_assignments.product_group_id)'
      }]
    ]
    add_fields CoreModule::VENDOR_PRODUCT_GROUP_ASSIGNMENT, make_vendor_arrays(100,'vpga','vendor_product_group_assignments')
  end
end; end; end
