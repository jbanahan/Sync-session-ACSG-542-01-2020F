module ConfigMigrations; module Www; class TalbotsSow1356

  def up
    add_business_validation_rules
  end

  def down
    remove_business_validation_rules
  end

  def add_business_validation_rules
    bvt = BusinessValidationTemplate.where(module_type: 'Entry', name: 'Talbots Entry').first_or_create!
    bvt.search_criterions.create!(operator: "eq", model_field_uid:"ent_cust_num", value:"TALBO")
    bvt.search_criterions.create!(operator: "ama", model_field_uid:"ent_file_logged_date", value:"12")
    bvt.update_attributes!(
        description:'Talbots entry rules',
        disabled: false
    )

    bvr1 = bvt.business_validation_rules.where(type:'ValidationRuleEntryInvoiceLineFieldFormat', name: 'Units').first_or_create!
    bvr1.update_attributes!(
        description: "Units must have a non-zero integer value.",
        fail_state: "Fail",
        rule_attributes_json: {
            "model_field_uid"=>"cil_units",
            "regex"=>"^([1-9][0-9]*)(\\.0)?*$"
        }.to_json,
        disabled: false
    )

    bvr2 = bvt.business_validation_rules.where(type:'ValidationRuleFieldFormat', name: 'Attachment').first_or_create!
    bvr2.update_attributes!(
        description: "Entry Packets must be attached to entries within 2 days of the Entry Release Date.",
        fail_state: "Fail",
        rule_attributes_json: {
            "model_field_uid"=>"ent_attachment_types",
            "regex"=>"ENTRY PACKET"
        }.to_json,
        disabled: false
    )

    bvr3 = bvt.business_validation_rules.where(type:'ValidationRuleEntryInvoiceLineFieldFormat', name: 'PO Number').first_or_create!
    bvr3.update_attributes!(
        description: "PO Number must contain exactly 7 digits.",
        fail_state: "Fail",
        rule_attributes_json: {
            "model_field_uid"=>"cil_po_number",
            "regex"=>"^\\d{7}$"
        }.to_json,
        disabled: false
    )

    bvr4 = bvt.business_validation_rules.where(type:'ValidationRuleEntryInvoiceLineFieldFormat', name: 'Part Number').first_or_create!
    bvr4.update_attributes!(
        description: "Part Number is required.",
        fail_state: "Fail",
        rule_attributes_json: {
            "model_field_uid"=>"cil_part_number",
            "regex"=>".+"
        }.to_json,
        disabled: false
    )

    bvr5 = bvt.business_validation_rules.where(type:'ValidationRuleFieldFormat', name: 'Customer References').first_or_create!
    bvr5.update_attributes!(
        description: "Customer references must fit a defined format of 4 alphanumeric characters, a period and 4-5 additional alphanumeric characters. Multiple numbers can be chained together, separated by commas.",
        fail_state: "Fail",
        rule_attributes_json: {
            "model_field_uid"=>"ent_customer_references",
            "regex"=>"^((\\w{4}\\.\\w{4,5})(,\\s*(\\w{4}\\.\\w{4,5}))*)?$"
        }.to_json,
        disabled: false
    )
  end

  def drop_business_validation_rules
    bvt = BusinessValidationTemplate.where(module_type: 'Entry', name: 'Talbots Entry').first
    bvt.destroy if bvt
  end

end; end; end