module OpenChain; module ModelFieldDefinition; module ProductVendorAssignmentFieldDefinition
  def add_product_vendor_assignment_fields
    add_fields CoreModule::PRODUCT_VENDOR_ASSIGNMENT, make_product_arrays(100,"pva","product_vendor_assignments")
    add_fields CoreModule::PRODUCT_VENDOR_ASSIGNMENT, make_vendor_arrays(200,"pva","product_vendor_assignments")

  end
end; end; end
